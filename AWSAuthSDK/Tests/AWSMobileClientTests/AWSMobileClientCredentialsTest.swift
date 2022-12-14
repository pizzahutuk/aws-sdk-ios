//
//  AWSMobileClientCredentialsTest.swift
//  AWSMobileClientTests
//

import XCTest

import AWSMobileClient
import AWSAuthCore
import AWSCognitoIdentityProvider
import AWSS3

/// AWSMobileClient tests related to AWS credentials
class AWSMobileClientCredentialsTest: AWSMobileClientTestBase {

    func testGetAWSCredentials() {
        let username = "testUser" + UUID().uuidString
        signUpAndVerifyUser(username: username)
        signIn(username: username)
        let credentialsExpectation = expectation(description: "Successfully fetch AWS Credentials")
        AWSMobileClient.default().getAWSCredentials { (credentials, error) in
            if let credentials = credentials {
                XCTAssertNotNil(credentials.accessKey)
                XCTAssertNotNil(credentials.secretKey)
            } else if let error = error {
                XCTFail("Unexpected failure: \(error.localizedDescription)")
            }
            credentialsExpectation.fulfill()
        }
        wait(for: [credentialsExpectation], timeout: 10)
    }
    
    func testUploadPrivateFile() {
        let username = "testUser" + UUID().uuidString
        signUpAndVerifyUser(username: username)
        signIn(username: username)
        let transferUtility = AWSS3TransferUtility.default()
        let verifyCredentialsExpectation = expectation(description: "Credentials should be retrieved successfully")
        AWSMobileClient.default().getAWSCredentials { (creds, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(creds)
            verifyCredentialsExpectation.fulfill()
        }
        wait(for: [verifyCredentialsExpectation], timeout: 10)
        
        guard let identityId = AWSMobileClient.default().identityId else {
            XCTFail("Could not find identityId to do private upload.")
            return
        }
        
        let uploadKey = "private/\(identityId)/file.txt"
        let uploadExpectation = expectation(description: "Successful file upload.")
        print("Uploading file to : \(uploadKey)")
        transferUtility.uploadData("Hello World".data(using: .utf8)!, key: uploadKey, contentType: "txt/plain", expression: nil) { (task, error) in
            XCTAssertNil(error)
            if let error = error {
                XCTFail("Upload File Failed: \(error.localizedDescription)")
            }
            uploadExpectation.fulfill()
        }
        wait(for: [uploadExpectation], timeout: 10)
    }
    
    func testDownloadPrivateFile() {
        let username = "testUser" + UUID().uuidString
        signUpAndVerifyUser(username: username)
        signIn(username: username)
        let transferUtility = AWSS3TransferUtility.default()
        let verifyCredentialsExpectation = expectation(description: "Credentials should be retrieved successfully")
        AWSMobileClient.default().getAWSCredentials { (creds, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(creds)
            verifyCredentialsExpectation.fulfill()
        }
        wait(for: [verifyCredentialsExpectation], timeout: 10)
        
        guard let identityId = AWSMobileClient.default().identityId else {
            XCTFail("Could not find identityId to do private upload.")
            return
        }
        
        let uploadKey = "private/\(identityId)/file.txt"
        let uploadExpectation = expectation(description: "Successful file upload.")
        let content = "Hello World"
        print("Uploading file to : \(uploadKey)")
        
        transferUtility.uploadData(content.data(using: .utf8)!, key: uploadKey, contentType: "txt/plain", expression: nil) { (task, error) in
            XCTAssertNil(error)
            if let error = error {
                XCTFail("Upload File Failed: \(error.localizedDescription)")
            }
            uploadExpectation.fulfill()
        }
        wait(for: [uploadExpectation], timeout: 10)
        
        let downloadExpectation = expectation(description: "Successful file download.")
        transferUtility.downloadData(forKey: uploadKey, expression: nil) { (task, url, data, error) in
            XCTAssertNil(error)
            if let error = error {
                XCTFail("Upload File Failed: \(error.localizedDescription)")
            }
            XCTAssertNotNil(data)
            if let data = data {
                let dataText = String(data: data, encoding: .utf8)
                XCTAssertEqual(dataText!, content, "Expecting uploaded and downloaded contents to be same.")
            }
            downloadExpectation.fulfill()
        }
        wait(for: [downloadExpectation], timeout: 10)
        
    }
    
    /// Test to check aws credentials fetched for unauth user
    ///
    /// - Given:
    ///     - An unauthenticated session
    ///     - AWSMobileClient configured to use Cognito with an unauthenticated role
    /// - When:
    ///    - I fetch AWS credentials
    /// - Then:
    ///    - I should get credentials
    ///
    func testUnAuthCredentialsForSignOutUser() {
        let verifyCredentialsExpectation = expectation(description: "Credentials should be retrieved successfully")
        AWSMobileClient.default().getAWSCredentials { (credentials, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(credentials)
            XCTAssertNotNil(credentials?.accessKey)
            XCTAssertNotNil(credentials?.secretKey)
            XCTAssertNotNil(credentials?.sessionKey)
            XCTAssertNotNil(credentials?.expiration)
            verifyCredentialsExpectation.fulfill()
        }
        wait(for: [verifyCredentialsExpectation], timeout: 10)
    }
    
    /// Test that upload to s3 fails for a signedOut user
    ///
    /// - Given: An unauthenticated session
    /// - When:
    ///    - I try to upload a file to S3
    /// - Then:
    ///    - I should get an error
    ///
    func testUploadFileWithSignOutUser() {

        let transferUtility = AWSS3TransferUtility.default()
        let verifyCredentialsExpectation = expectation(description: "Credentials should be retrieved successfully")
        AWSMobileClient.default().getAWSCredentials { (_, _) in
            verifyCredentialsExpectation.fulfill()
        }
        wait(for: [verifyCredentialsExpectation], timeout: 10)
        
        XCTAssertFalse(AWSMobileClient.default().isSignedIn, "User should be in signOut state")
        let uploadKey = "private/file.txt"
        let s3UploadDataCompletionExpectation = expectation(description: "S3 transfer utility uploadData task completed")
        let content = "Hello World"
        print("Uploading file to : \(uploadKey)")
        
        transferUtility.uploadData(content.data(using: .utf8)!,
                                   key: uploadKey,
                                   contentType: "text/plain",
                                   expression: nil) { (_, error) in
            defer {
                s3UploadDataCompletionExpectation.fulfill()
            }
            guard let error = error as NSError? else {
                XCTFail("Error unexpectedly nil")
                return
            }
            XCTAssertEqual(error.domain, AWSS3TransferUtilityErrorDomain)
            XCTAssertEqual(error.code, AWSS3TransferUtilityErrorType.clientError.rawValue)
        }
        wait(for: [s3UploadDataCompletionExpectation], timeout: 10)
    }
    
    /// Test that S3 upload works if we call it inside the user state listener
    ///
    /// - Given: An unauthenticated session
    /// - When:
    ///    - I invoke signIn
    ///    - I invoke upload to s3 inside the user state listener for signedIn case
    /// - Then:
    ///    - I should be able to upload to S3 without any error
    ///
    func testUploadFileInUserStateListener() {
        let username = "testUser" + UUID().uuidString
        let transferUtility = AWSS3TransferUtility.default()
        let content = "Hello World"
        let s3UploadDataCompletionExpectation = expectation(description: "S3 transfer utility uploadData task completed")
        let signInListenerWasSuccessful = expectation(description: "signIn listener was successful")
        
        AWSMobileClient.default().addUserStateListener(self) { (userState, info) in
            defer {
                signInListenerWasSuccessful.fulfill()
            }
            
            guard userState == .signedIn else {
                XCTFail("User state should be signed In")
                return
            }

            AWSMobileClient.default().getIdentityId().continueWith { task in
                if let error = task.error {
                    XCTAssertNil(error, "Unexpected error in getIdentityId()")
                    return nil
                }

                guard let identityId = task.result else {
                    XCTFail("task.result unexpectedly nil")
                    return nil
                }

                let uploadKey = "private/\(identityId)/file.txt"
                transferUtility.uploadData(
                    content.data(using: .utf8)!,
                    key: uploadKey,
                    contentType: "text/plain",
                    expression: nil
                ) { _, error in
                    XCTAssertNil(error)
                    s3UploadDataCompletionExpectation.fulfill()
                }
                return nil
            }

        }

        signUpAndVerifyUser(username: username)
        signIn(username: username)
        wait(for: [signInListenerWasSuccessful, s3UploadDataCompletionExpectation], timeout: 10)
        AWSMobileClient.default().removeUserStateListener(self)
    }
    
    func testMultipleGetCredentials() {
        AWSDDLog.add(AWSDDTTYLogger.sharedInstance)
        let username = "testUser" + UUID().uuidString
        let credentialFetchBeforeSignIn = expectation(description: "Request to getAWSCredentials before signIn")
        let credentialFetchAfterSignIn = expectation(description: "Request to getAWSCredentials after signIn")
        let credentialFetchAfterSignIn2 = expectation(description: "Request to getAWSCredentials after signIn")
        let credentialFetchAfterSignOut = expectation(description: "Request to getAWSCredentials after signOut")
        AWSMobileClient.default().getAWSCredentials({ (awscredentials, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(awscredentials, "Credentials should not return nil.")
            credentialFetchBeforeSignIn.fulfill()
        })
        signUpAndVerifyUser(username: username)
        signIn(username: username)
        AWSMobileClient.default().getAWSCredentials({ (awscredentials, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(awscredentials, "Credentials should not return nil.")
            credentialFetchAfterSignIn.fulfill()
        })
        wait(for: [credentialFetchAfterSignIn], timeout: 15)
        
        AWSMobileClient.default().getAWSCredentials({ (awscredentials, error) in
            // We do not need to check the values here, this can succeed
            // or fail based on whether this method completes before the below signOut.
            credentialFetchAfterSignIn2.fulfill()
        })
        AWSMobileClient.default().signOut()
        AWSMobileClient.default().getAWSCredentials({ (awscredentials, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(awscredentials, "Credentials should not return nil.")
            credentialFetchAfterSignOut.fulfill()
        })
        wait(for: [credentialFetchAfterSignIn2, credentialFetchBeforeSignIn, credentialFetchAfterSignOut], timeout: 15)
    }


    func testMultipleConcurrentGetCredentials() {
        AWSDDLog.add(AWSDDTTYLogger.sharedInstance)
        let username = "testUser" + UUID().uuidString
        let credentialFetchAfterSignIn = expectation(description: "Request to getAWSCredentials after signIn")
        let credentialFetchAfterSignOut = expectation(description: "Request to getAWSCredentials after signOut")

        signUpAndVerifyUser(username: username)
        signIn(username: username)
        credentialFetchAfterSignIn.expectedFulfillmentCount = 100
        for _ in 1...100 {
            DispatchQueue.global().async {
                AWSMobileClient.default().getAWSCredentials({ (awscredentials, error) in
                    XCTAssertNil(error)
                    XCTAssertNotNil(awscredentials, "Credentials should not return nil.")
                    credentialFetchAfterSignIn.fulfill()
                })
            }}

        wait(for: [credentialFetchAfterSignIn], timeout: 25)

        AWSMobileClient.default().signOut()
        AWSMobileClient.default().getAWSCredentials({ (awscredentials, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(awscredentials, "Credentials should not return nil.")
            credentialFetchAfterSignOut.fulfill()
        })
        wait(for: [credentialFetchAfterSignOut], timeout: 15)
    }
    
    /// Test AWS credentials fetched for different user are different
    ///
    /// - Given: An authenticated session with valid aws crdentials
    /// - When:
    ///    - I invoke signout
    ///    - I signIn with a different user
    ///    - I fetch AWS credentials
    /// - Then:
    ///    - The AWS credentials should be different from the initial value
    ///
    func testGetAWSCredentialsForMultipleUser() {
        let username_1 = "testUser" + UUID().uuidString
        signUpAndVerifyUser(username: username_1)
        
        let username_2 = "testUser" + UUID().uuidString
        signUpAndVerifyUser(username: username_2)
        
        signIn(username: username_1)
        let credentialsExpectation_1 = expectation(description: "Successfully fetch AWS Credentials")
        
        var accessToken_1: String? = nil
        AWSMobileClient.default().getAWSCredentials { (credentials, error) in
            if let credentials = credentials {
                XCTAssertNotNil(credentials.accessKey)
                XCTAssertNotNil(credentials.secretKey)
                accessToken_1 = credentials.accessKey
            } else if let error = error {
                XCTFail("Unexpected failure: \(error.localizedDescription)")
            }
            credentialsExpectation_1.fulfill()
        }
        wait(for: [credentialsExpectation_1], timeout: 10)
        
        AWSMobileClient.default().signOut()
        
        signIn(username: username_2)
        let credentialsExpectation_2 = expectation(description: "Successfully fetch AWS Credentials")
        
        var accessToken_2: String? = nil
        AWSMobileClient.default().getAWSCredentials { (credentials, error) in
            if let credentials = credentials {
                XCTAssertNotNil(credentials.accessKey)
                XCTAssertNotNil(credentials.secretKey)
                accessToken_2 = credentials.accessKey
            } else if let error = error {
                XCTFail("Unexpected failure: \(error.localizedDescription)")
            }
            credentialsExpectation_2.fulfill()
        }
        wait(for: [credentialsExpectation_2], timeout: 10)
        XCTAssertNotEqual(accessToken_1, accessToken_2, "AWS Access token of two user should not match")
    }
    
    /// Test AWS credentials fetched for different user are different
    ///
    /// - Given: An authenticated session with valid aws crdentials
    /// - When:
    ///    - I invoke signout
    ///    - I manually expire Cognito token
    ///    - Sign in to refresh Cognito tokens
    ///    - I fetch AWS credentials
    /// - Then:
    ///    - The AWS credentials should be different from the initial value
    ///
    func testGetAWSCredentialsForMultipleUserDuringTokenRefresh() {
        let username_1 = "testUser" + UUID().uuidString
        signUpAndVerifyUser(username: username_1)
        
        let username_2 = "testUser" + UUID().uuidString
        signUpAndVerifyUser(username: username_2)
        
        signIn(username: username_1)
        let credentialsExpectation_1 = expectation(description: "Successfully fetch AWS Credentials")
        
        var accessToken_1: String? = nil
        AWSMobileClient.default().getAWSCredentials { (credentials, error) in
            if let credentials = credentials {
                XCTAssertNotNil(credentials.accessKey)
                XCTAssertNotNil(credentials.secretKey)
                accessToken_1 = credentials.accessKey
            } else if let error = error {
                XCTFail("Unexpected failure: \(error.localizedDescription)")
            }
            credentialsExpectation_1.fulfill()
        }
        wait(for: [credentialsExpectation_1], timeout: 10)
        
        // Setup a listener to signIn with a different user whenever you get signedOutUserPoolsTokenInvalid
        AWSMobileClient.default().addUserStateListener(self) { (userstate, info) in
            if (userstate == .signedOutUserPoolsTokenInvalid) {
                DispatchQueue.main.async {
                    self.signIn(username: username_2)
                }
            }
        }
        // Now invalidate the session and then try to call getToken
        self.invalidateRefreshToken(username: username_1)

        let tokenFetchFailExpectation = expectation(description: "Token fetch should complete")
        AWSMobileClient.default().getTokens { (token, error) in
            tokenFetchFailExpectation.fulfill()
        }
        wait(for: [tokenFetchFailExpectation], timeout: 10)
        
        let credentialsExpectation_2 = expectation(description: "Successfully fetch AWS Credentials")
        
        var accessToken_2: String? = nil
        AWSMobileClient.default().getAWSCredentials { (credentials, error) in
            if let credentials = credentials {
                XCTAssertNotNil(credentials.accessKey)
                XCTAssertNotNil(credentials.secretKey)
                accessToken_2 = credentials.accessKey
            } else if let error = error {
                XCTFail("Unexpected failure: \(error.localizedDescription)")
            }
            credentialsExpectation_2.fulfill()
        }
        wait(for: [credentialsExpectation_2], timeout: 10)
        XCTAssertNotEqual(accessToken_1, accessToken_2, "AWS Access token of two user should not match")
        AWSMobileClient.default().removeUserStateListener(self)
    }
}
