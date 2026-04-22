import Foundation
import Testing
@testable import MBAPI

@Suite(.serialized)
struct MBAPITests {

    @Test func liveClientRequestsParentChildrenEndpoint() async throws {
        let session = makeStubSession(
            statusCode: 200,
                        body: #"""
                        {
                            "items": [
                                {
                                    "id": 123,
                                    "full_name": "Maya Danmayer",
                                    "normalized_full_name": "Danmayer, Maya",
                                    "role_id": "student",
                                    "role": "Student",
                                    "url": "https://school.managebac.com/parent/academics/child_profile?child=123",
                                    "email": "maya@example.com",
                                    "labels": [
                                        {
                                            "title": "Student",
                                            "style": {
                                                "text_color": "#1570ef",
                                                "border_color": "#1570ef",
                                                "background_color": "#eff8ff"
                                            },
                                            "color": "#4b8ffa"
                                        }
                                    ],
                                    "photo_url": "https://school.managebac.com/photo.jpg",
                                    "initials": "MD"
                                }
                            ]
                        }
                        """#
        )
        let client = MBLiveClient(session: session)

        let children = try await client.listChildren(
            in: MBSessionContext(
                apiBaseURL: URL(string: "https://school.managebac.com/api/mobile")!,
                accessToken: "access-token"
            )
        )

        #expect(URLProtocolStub.lastRequestURL?.absoluteString == "https://school.managebac.com/api/mobile/parent/children")
        #expect(URLProtocolStub.lastAuthorizationHeader == "Bearer access-token")
        #expect(children == [
            MBChild(
                id: "123",
                displayName: "Maya Danmayer",
                normalizedFullName: "Danmayer, Maya",
                roleID: "student",
                role: "Student",
                profileURL: URL(string: "https://school.managebac.com/parent/academics/child_profile?child=123"),
                email: "maya@example.com",
                labels: [
                    MBChildLabel(
                        title: "Student",
                        style: MBChildLabelStyle(
                            textColor: "#1570ef",
                            borderColor: "#1570ef",
                            backgroundColor: "#eff8ff"
                        ),
                        color: "#4b8ffa"
                    )
                ],
                initials: "MD",
                avatarURL: URL(string: "https://school.managebac.com/photo.jpg")
            )
        ])
    }

    @Test func liveClientRequestsPortfolioTimelineDecodesLabelsAsStrings() async throws {
        let session = makeStubSession(
            statusCode: 200,
            body: #"""
            {
                "items": [
                    {
                        "id": 78749910,
                        "logable_type": "PortfolioResource",
                        "status": "added",
                        "created_at": "2025-06-13T18:16:52.000+03:00",
                        "logable": {
                            "id": 2065921,
                            "start_date": "2027-12-05",
                            "created_at": "2025-06-13T18:16:52.000+03:00",
                            "gid": "eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJamxuYVdRNkx5OXRZVzVoWjJWaVlXTXZVRzl5ZEdadmJHbHZVbVZ6YjNWeVkyVXZNakEyTlRreU1UOWxlSEJwY21WelgybHVCam9HUlZRPSIsImV4cCI6bnVsbCwicHVyIjoiZGVmYXVsdCJ9fQ",
                            "starred": true,
                            "liked": false,
                            "likes_count": 0,
                            "connections_count": 0,
                            "comments_count": 2,
                            "can_comment": true,
                            "can_edit": false,
                            "can_delete": false,
                            "can_like": true,
                            "can_star": true,
                            "can_export": false,
                            "can_connect": false,
                            "allowed_user_roles": [],
                            "atl_ids": [],
                            "learner_profile_ids": [],
                            "title": "",
                            "kind": "file",
                            "share_to_student_portfolios": false,
                            "description": "",
                            "units_standard_ids": [],
                            "units_syllabus_ids": [],
                            "units_expectation_ids": [],
                            "transdisciplinary_themes_ids": [],
                            "transdisciplinary_theme_descriptions_ids": [],
                            "created_by": {
                                "photo_url": "https://cdn.ca.managebac.com/uploads/photo/file/27966074/1/chloe.jpeg?Expires=1775606267&Signature=abc",
                                "id": 14088555,
                                "initials": "CE",
                                "full_name": "Chloe Epelbaum",
                                "normalized_full_name": "Epelbaum, Chloe",
                                "role_id": "student",
                                "role": "Student",
                                "url": "https://faria.managebac.com/parent/academics/child_profile?child=14088555",
                                "email": "chloe@eduvo.com",
                                "labels": [
                                    {
                                        "title": "Student",
                                        "style": {
                                            "text_color": "#1570ef",
                                            "border_color": "#1570ef",
                                            "background_color": "#eff8ff"
                                        },
                                        "color": "#4b8ffa"
                                    }
                                ]
                            },
                            "labels": [
                                {
                                    "title": "Photo",
                                    "style": {
                                        "text_color": "#1570ef",
                                        "border_color": "#1570ef",
                                        "background_color": "#eff8ff"
                                    },
                                    "color": "#4b8ffa"
                                }
                            ],
                            "assets": [],
                            "assigned_users": [],
                            "standards": [],
                            "syllabuses": [],
                            "expectations": []
                        },
                        "labels": [
                            {
                                "title": "Timeline",
                                "style": {
                                    "text_color": "#1570ef",
                                    "border_color": "#1570ef",
                                    "background_color": "#eff8ff"
                                },
                                "color": "#4b8ffa"
                            }
                        ]
                    },
                    {
                        "id": 87019181,
                        "logable_type": "CorePortfolioEventSubmission",
                        "status": "added",
                        "created_at": "2026-03-30T11:52:31.000+03:00",
                        "logable": {
                            "id": 81501103,
                            "start_date": "2026-03-30",
                            "created_at": "2026-03-30T11:52:31.000+03:00",
                            "gid": "eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJa1ZuYVdRNkx5OXRZVzVoWjJWaVlXTXZRMjl5WlZCdmNuUm1iMnhwYjBWMlpXNTBVM1ZpYldsemMybHZiaTg0TVRBeE9USTJORDlsZUhCcGNtVnpYMmx1QmpvR1JWUT0iLCJleHAiOm51bGwsInB1ciI6ImRlZmF1bHQifX0=--eca06158d781f25a66203546cc376105d5bcff13",
                            "starred": false,
                            "liked": false,
                            "likes_count": 0,
                            "connections_count": 0,
                            "comments_count": 0,
                            "can_comment": true,
                            "can_edit": false,
                            "can_delete": false,
                            "can_like": true,
                            "can_star": true,
                            "can_export": false,
                            "can_connect": false,
                            "allowed_user_roles": [],
                            "atl_ids": [],
                            "learner_profile_ids": [],
                            "created_by": {
                                "photo_url": "https://cdn.ca.managebac.com/uploads/photo/file/27966074/1/chloe.jpeg?Expires=1775606424&Signature=def",
                                "id": 14088555,
                                "initials": "CE",
                                "full_name": "Chloe Epelbaum",
                                "normalized_full_name": "Epelbaum, Chloe",
                                "role_id": "student",
                                "role": "Student",
                                "url": "https://faria.managebac.com/parent/academics/child_profile?child=14088555",
                                "email": "chloe@eduvo.com",
                                "labels": [
                                    {
                                        "title": "Student",
                                        "style": {
                                            "text_color": "#1570ef",
                                            "border_color": "#1570ef",
                                            "background_color": "#eff8ff"
                                        },
                                        "color": "#4b8ffa"
                                    }
                                ]
                            },
                            "labels": [
                                {
                                    "title": "Submitted",
                                    "style": {
                                        "text_color": "#039855",
                                        "border_color": "#039855",
                                        "background_color": "#ecfdf3"
                                    },
                                    "color": "#339933"
                                }
                            ],
                            "event": {
                                "url": "https://faria.managebac.com/parent/classes/12937376/tasks/47658262?child=14088555",
                                "type": "AssessmentTask",
                                "id": 47658262,
                                "name": "PDFkit",
                                "group_id": 12937376,
                                "start_at": "2026-03-30T11:50:00.000+03:00",
                                "bgcolor": "#FFAD3A",
                                "fgcolor": "#fff",
                                "all_day": false,
                                "txtcolor": "#FFAD3A",
                                "category": "Test",
                                "group_name": "IB DP Class to Check IA (Grade 9)",
                                "group_type": "Class",
                                "gid": "eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJakZuYVdRNkx5OXRZVzVoWjJWaVlXTXZRWE56WlhRdk1UZzBPREV6YVdkdWJXVnVkQzgwTmpZNE1ETTRNRDlsZUhCcGNtVnpYMmx1QmpvR1JWUT0iLCJleHAiOm51bGwsInB1ciI6ImRlZmF1bHQifX0",
                                "dropbox_id": 25084257,
                                "labels": [
                                    {
                                        "title": "Test",
                                        "style": {
                                            "text_color": "#FFAD3A",
                                            "border_color": "#FFAD3A",
                                            "background_color": "#1fFFAD3A"
                                        },
                                        "color": "#FFAD3A",
                                        "text_color": "#fff"
                                    }
                                ],
                                "actions": []
                            },
                            "assets": [
                                {
                                    "id": 185781922,
                                    "gid": "eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaTluYVdRNkx5OXRZVzVoWjJWaVlXTXZRWE56WlhRdk1UZzBOelUyTVRjMFAyVjRjR2x5WlhOZmFXNEdPZ1pGVkE9PSIsImV4cCI6bnVsbCwicHVyIjoiZGVmYXVsdCJ9fQ==--34effad",
                                    "filename": "submission.pdf",
                                    "filesize": "30 KB",
                                    "filetype": "PDF Document",
                                    "url": "https://cdn.ca.managebac.com/uploads/asset/file/185781922/sample.pdf",
                                    "uploaded_at": "2026-03-30T11:50:00.000+03:00",
                                    "author": {
                                        "photo_url": "https://cdn.ca.managebac.com/uploads/photo/file/27966074/1/chloe.jpeg",
                                        "id": 14088555,
                                        "initials": "CE",
                                        "full_name": "Chloe Epelbaum",
                                        "normalized_full_name": "Epelbaum, Chloe",
                                        "role_id": "student",
                                        "role": "Student"
                                    }
                                }
                            ]
                        },
                        "labels": [
                            {
                                "title": "Submission",
                                "style": {
                                    "text_color": "#1570ef",
                                    "border_color": "#1570ef",
                                    "background_color": "#eff8ff"
                                },
                                "color": "#4b8ffa"
                            }
                        ]
                    }
                ],
                "meta": {
                    "total": 241,
                    "total_pages": 25,
                    "page": 1,
                    "per_page": 10
                }
            }
            """#
        )
        let client = MBLiveClient(session: session)

        let timeline = try await client.listPortfolioTimeline(
            in: MBSessionContext(
                apiBaseURL: URL(string: "https://school.managebac.com/api/mobile")!,
                accessToken: "access-token"
            )
        )

        #expect(URLProtocolStub.lastRequestURL?.absoluteString == "https://school.managebac.com/api/mobile/parent/portfolio/timeline")
        #expect(timeline.count == 2)
        #expect(timeline.first?.logableType == "PortfolioResource")
        #expect(timeline.first?.labels == ["Timeline"])
        #expect(timeline.first?.logable.labels == ["Photo"])
        #expect(timeline.first?.logable.createdBy?.labels == ["Student"])
        #expect(timeline[1].logableType == "CorePortfolioEventSubmission")
        #expect(timeline[1].labels == ["Submission"])
        #expect(timeline[1].logable.labels == ["Submitted"])
        #expect(timeline[1].logable.createdBy?.labels == ["Student"])
        #expect(timeline[1].logable.event?.groupID == "12937376")
        #expect(timeline[1].logable.event?.startAt == "2026-03-30T11:50:00.000+03:00")
    }

    @Test func liveClientReportsUnexpectedStatusCodes() async {
        let session = makeStubSession(statusCode: 401, body: #"{"error":"unauthorized"}"#)
        let client = MBLiveClient(session: session)

        await #expect(throws: MBClientError.unexpectedStatusCode(401)) {
            try await client.listChildren(
                in: MBSessionContext(
                    apiBaseURL: URL(string: "https://school.managebac.com/api/mobile")!,
                    accessToken: "access-token"
                )
            )
        }
    }

    @Test func liveClientRequestsParentAssociationFilesEndpointWithChildContext() async throws {
        let session = makeStubSession(
            statusCode: 200,
            body: #"""
            {
                "items": [
                    {
                        "item_type": "Folder",
                        "item": {
                            "id": 14,
                            "name": "Meeting Minutes",
                            "updated_at": "2026-04-08T08:00:00Z"
                        }
                    }
                ]
            }
            """#
        )
        let client = MBLiveClient(session: session)

        let files = try await client.listParentAssociationFiles(
            in: MBSessionContext(
                apiBaseURL: URL(string: "https://school.managebac.com/api/mobile")!,
                accessToken: "access-token",
                childID: "123"
            )
        )

        #expect(URLProtocolStub.lastRequestURL?.absoluteString == "https://school.managebac.com/api/mobile/parent/pa/files?child_id=123")
        #expect(files.count == 1)
        #expect(files.first?.itemType == .folder)
        #expect(files.first?.folder?.name == "Meeting Minutes")
    }

    @Test func requestorWritesDecodingFailuresToIssueLogFolder() async throws {
        let logsDirectoryURL = makeTemporaryLogsDirectory()
        let session = makeStubSession(
            statusCode: 200,
            body: #"{"items":[{"id":1}]}"#
        )
        let requestor = MBAPIRequestor(
            session: session,
            decoder: JSONDecoder(),
            issueLogger: MBAPIIssueLogger(logsDirectoryURL: logsDirectoryURL)
        )

        do {
            _ = try await requestor.loadItems(
                as: MBChild.self,
                from: "parent/children",
                in: MBSessionContext(
                    apiBaseURL: URL(string: "https://school.managebac.com/api/mobile")!,
                    accessToken: "access-token"
                )
            ) as [MBChild]
            Issue.record("Expected decoding to fail")
        } catch let error as MBClientError {
            if case .decodingFailed = error {
                #expect(true)
            } else {
                Issue.record("Expected decodingFailed, got \(error)")
            }
        }

        let logEntry = try latestIssueLog(in: logsDirectoryURL)
        #expect(logEntry["kind"] as? String == "decodingFailed")
        #expect(logEntry["requestURL"] as? String == "https://school.managebac.com/api/mobile/parent/children")
        #expect(logEntry["responseType"] as? String == "MBChild")
        #expect((logEntry["responseBody"] as? String)?.contains("\"id\":1") == true)
    }

    @Test func requestorWritesUnexpectedStatusToIssueLogFolder() async throws {
        let logsDirectoryURL = makeTemporaryLogsDirectory()
        let session = makeStubSession(
            statusCode: 401,
            body: #"{"error":"unauthorized"}"#
        )
        let requestor = MBAPIRequestor(
            session: session,
            decoder: JSONDecoder(),
            issueLogger: MBAPIIssueLogger(logsDirectoryURL: logsDirectoryURL)
        )

        await #expect(throws: MBClientError.unexpectedStatusCode(401)) {
            _ = try await requestor.loadItems(
                as: MBChild.self,
                from: "parent/children",
                in: MBSessionContext(
                    apiBaseURL: URL(string: "https://school.managebac.com/api/mobile")!,
                    accessToken: "access-token"
                )
            ) as [MBChild]
        }

        let logEntry = try latestIssueLog(in: logsDirectoryURL)
        #expect(logEntry["kind"] as? String == "unexpectedStatusCode")
        #expect(logEntry["statusCode"] as? Int == 401)
        #expect((logEntry["responseBody"] as? String)?.contains("unauthorized") == true)
    }

    @Test func liveClientRequestsParentClassesEndpointWithChildContext() async throws {
        let session = makeStubSession(
            statusCode: 200,
            body: #"""
            {
                "items": [
                    {
                        "id": 42,
                        "name": "IB DP Biology",
                        "icon": "biology",
                        "labels": [
                            {
                                "title": "HL",
                                "style": {
                                    "text_color": "#175cd3",
                                    "border_color": "#b2ddff",
                                    "background_color": "#d1e9ff"
                                }
                            }
                        ],
                        "url": "https://school.managebac.com/parent/classes/42",
                        "locked": false,
                        "member": true,
                        "program": {
                            "uid": 7,
                            "code": "diploma",
                            "name": "Diploma Programme",
                            "short_name": "DP",
                            "icon": "dp",
                            "color": "#4B8FFA"
                        },
                        "uniq_id": "class-42",
                        "default_term": {
                            "id": 3,
                            "name": "Semester 1"
                        },
                        "terms": [
                            {
                                "id": 3,
                                "name": "Semester 1"
                            }
                        ]
                    }
                ]
            }
            """#
        )
        let client = MBLiveClient(session: session)

        let classes = try await client.listClasses(
            in: MBSessionContext(
                apiBaseURL: URL(string: "https://school.managebac.com/api/mobile")!,
                accessToken: "access-token",
                childID: "123"
            )
        )

        #expect(URLProtocolStub.lastRequestURL?.absoluteString == "https://school.managebac.com/api/mobile/parent/classes/roster?child_id=123&per_page=100")
        #expect(classes == [
            MBClass(
                id: "42",
                displayName: "IB DP Biology",
                iconName: "biology",
                labels: [
                    MBClassLabel(
                        title: "HL",
                        style: MBChildLabelStyle(
                            textColor: "#175cd3",
                            borderColor: "#b2ddff",
                            backgroundColor: "#d1e9ff"
                        )
                    )
                ],
                detailURL: URL(string: "https://school.managebac.com/parent/classes/42"),
                isLocked: false,
                isMember: true,
                program: MBClassProgram(
                    uid: "7",
                    code: "diploma",
                    name: "Diploma Programme",
                    shortName: "DP",
                    iconName: "dp",
                    color: "#4B8FFA"
                ),
                uniqueID: "class-42",
                defaultTerm: MBClassTerm(id: "3", name: "Semester 1"),
                terms: [MBClassTerm(id: "3", name: "Semester 1")]
            )
        ])
    }

    @Test func advisorRoleUsesTeacherURLSegmentForClassesEndpoint() async throws {
        let session = makeStubSession(
            statusCode: 200,
            body: #"{"items":[]}"#
        )
        let client = MBLiveClient(session: session)

        _ = try await client.listClasses(
            in: MBSessionContext(
                apiBaseURL: URL(string: "https://school.managebac.com/api/mobile")!,
                accessToken: "access-token",
                role: .advisor
            )
        )

        #expect(MBAPIRole.advisor.rawValue == "advisor")
        #expect(MBAPIRole.advisor.urlPathComponent == "teacher")
        #expect(URLProtocolStub.lastRequestURL?.absoluteString == "https://school.managebac.com/api/mobile/teacher/classes/roster/my?per_page=100")
    }

    @Test func advisorRoleUsesTeacherURLSegmentForPortfolioEndpoint() async throws {
        let session = makeStubSession(
            statusCode: 200,
            body: #"{"items":[]}"#
        )
        let client = MBLiveClient(session: session)

        _ = try await client.listPortfolioTimeline(
            in: MBSessionContext(
                apiBaseURL: URL(string: "https://school.managebac.com/api/mobile")!,
                accessToken: "access-token",
                role: .advisor
            ),
            classID: "42",
            query: [:]
        )

        #expect(URLProtocolStub.lastRequestURL?.absoluteString == "https://school.managebac.com/api/mobile/teacher/portfolio/classes/42/timeline")
    }

    @Test func liveClientRequestsSchoolThemesWithoutRolePrefix() async throws {
        let session = makeStubSession(
            statusCode: 200,
            body: #"""
            {
                "items": [
                    {
                        "data": {
                            "id": 3,
                            "icon": "sebo_express",
                            "title": "How we express ourselves",
                            "list": [
                                {
                                    "year": 2024,
                                    "label": "An inquiry into the diversity of voice, perspectives, and expression through:",
                                    "options": [
                                        {
                                            "id": 33,
                                            "name": "inspiration, imagination, creativity"
                                        }
                                    ]
                                }
                            ]
                        }
                    }
                ]
            }
            """#
        )
        let client = MBLiveClient(session: session)

        let themes = try await client.loadSchoolThemes(
            in: MBSessionContext(
                apiBaseURL: URL(string: "https://school.managebac.com/api/mobile")!,
                accessToken: "access-token",
                role: .teacher
            )
        )

        #expect(URLProtocolStub.lastRequestURL?.absoluteString == "https://school.managebac.com/api/mobile/school/tr_themes")
        #expect(themes == [
            MBTRTheme(
                id: "3",
                name: "How we express ourselves",
                descriptions: [
                    MBTRThemeDescription(
                        id: "33",
                        name: "inspiration, imagination, creativity",
                        year: 2024,
                        label: "An inquiry into the diversity of voice, perspectives, and expression through:"
                    )
                ]
            )
        ])
    }
}

private func makeStubSession(statusCode: Int, body: String) -> URLSession {
    URLProtocolStub.lastAuthorizationHeader = nil
    URLProtocolStub.lastRequestURL = nil
    URLProtocolStub.response = HTTPURLResponse(
        url: URL(string: "https://school.managebac.com/api/mobile/parent/children")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )
    URLProtocolStub.responseData = Data(body.utf8)

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    return URLSession(configuration: configuration)
}

private func makeTemporaryLogsDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
}

private func latestIssueLog(in directoryURL: URL) throws -> [String: Any] {
    let fileURLs = try FileManager.default.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
    )
    let latestFileURL = try #require(
        fileURLs.max { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate < rhsDate
        }
    )

    let data = try Data(contentsOf: latestFileURL)
    let jsonObject = try JSONSerialization.jsonObject(with: data)
    return try #require(jsonObject as? [String: Any])
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var response: URLResponse?
    nonisolated(unsafe) static var lastAuthorizationHeader: String?
    nonisolated(unsafe) static var lastRequestURL: URL?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequestURL = request.url
        Self.lastAuthorizationHeader = request.value(forHTTPHeaderField: "Authorization")

        if let response = Self.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
