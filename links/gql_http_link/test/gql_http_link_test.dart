import "dart:async";
import "dart:convert";

import "package:gql_exec/gql_exec.dart";
import "package:gql/language.dart";
import "package:gql_http_link/gql_http_link.dart";
import "package:gql_link/gql_link.dart";
import "package:http/http.dart" as http;
import "package:mockito/mockito.dart";
import "package:test/test.dart";

import "./helpers.dart";

class MockClient extends Mock implements http.Client {}

class MockRequestSerializer extends Mock implements RequestSerializer {}

class MockResponseParser extends Mock implements ResponseParser {}

void main() {
  group("HttpLink", () {
    MockClient client;
    Request request;
    HttpLink link;

    final Stream<Response> Function([
      Request customRequest,
    ]) execute = ([
      Request customRequest,
    ]) =>
        link.request(customRequest ?? request);

    setUp(() {
      client = MockClient();
      request = Request(
        operation: Operation(
          document: parseString("query MyQuery {}"),
        ),
        variables: const <String, dynamic>{"i": 12},
      );
      link = HttpLink(
        "/graphql-test",
        httpClient: client,
      );
    });

    test("parses a successful response", () {
      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          simpleResponse(
            json.encode(<String, dynamic>{
              "data": <String, dynamic>{},
            }),
            200,
          ),
        ),
      );

      expect(
        execute(),
        emitsInOrder(<dynamic>[
          Response(
            data: const <String, dynamic>{},
            errors: null,
            context: Context()
                .withEntry(
                  ResponseExtensions(null),
                )
                .withEntry(
                  HttpLinkResponseContext(statusCode: 200),
                ),
          ),
          emitsDone,
        ]),
      );
    });

    test("uses the defined endpoint", () async {
      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          simpleResponse(
            json.encode(<String, dynamic>{
              "data": <String, dynamic>{},
            }),
            200,
          ),
        ),
      );

      await execute().first;

      verify(client.send(any)).called(1);
    });

    test("uses json mime types", () async {
      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          simpleResponse(
            json.encode(<String, dynamic>{
              "data": <String, dynamic>{},
            }),
            200,
          ),
        ),
      );

      await execute().first;

      verify(client.send(any)).called(1);
    });

    test("adds headers from context", () async {
      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          simpleResponse(
            json.encode(<String, dynamic>{
              "data": <String, dynamic>{},
            }),
            200,
          ),
        ),
      );

      await execute(
        Request(
          operation: Operation(
            document: parseString("query MyQuery {}"),
          ),
          variables: const <String, dynamic>{"i": 12},
          context: Context.fromList(
            const [
              HttpLinkHeaders(
                headers: {
                  "foo": "bar",
                },
              ),
            ],
          ),
        ),
      ).first;

      verify(client.send(any)).called(1);
    });

    test("adds default headers", () async {
      final client = MockClient();
      final link = HttpLink(
        "/graphql-test",
        httpClient: client,
        defaultHeaders: {
          "foo": "bar",
        },
      );

      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          simpleResponse(
            json.encode(<String, dynamic>{
              "data": <String, dynamic>{},
            }),
            200,
          ),
        ),
      );

      await link
          .request(
            Request(
              operation: Operation(
                document: parseString("query MyQuery {}"),
              ),
              variables: const <String, dynamic>{"i": 12},
            ),
          )
          .first;

      verify(client.send(any)).called(1);
    });

    test("headers from context override defaults", () async {
      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          simpleResponse(
            json.encode(<String, dynamic>{
              "data": <String, dynamic>{},
            }),
            200,
          ),
        ),
      );

      await execute(
        Request(
          operation: Operation(
            document: parseString("query MyQuery {}"),
          ),
          variables: const <String, dynamic>{"i": 12},
          context: Context.fromList(
            const [
              HttpLinkHeaders(
                headers: {
                  "Content-type": "application/jsonize",
                },
              ),
            ],
          ),
        ),
      ).first;

      verify(client.send(any)).called(1);
    });

    test("serializes the request", () async {
      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          simpleResponse(
            json.encode(<String, dynamic>{
              "data": <String, dynamic>{},
            }),
            200,
          ),
        ),
      );

      await execute().first;

      verify(client.send(any)).called(1);
    });

    test("parses a successful response with errors", () async {
      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          simpleResponse(
            json.encode(
              <String, dynamic>{
                "errors": <Map<String, dynamic>>[
                  <String, dynamic>{
                    "message": "Execution error",
                    "path": <dynamic>["friends", 0, "name"],
                    "extensions": <String, dynamic>{},
                    "locations": <Map<String, dynamic>>[
                      <String, dynamic>{
                        "line": 1,
                        "column": 1,
                      },
                    ],
                  },
                ],
                "data": <String, dynamic>{},
              },
            ),
            200,
          ),
        ),
      );

      expect(
        execute(),
        emitsInOrder(<dynamic>[
          Response(
            data: const <String, dynamic>{},
            errors: const [
              GraphQLError(
                message: "Execution error",
                path: <dynamic>["friends", 0, "name"],
                extensions: <String, dynamic>{},
                locations: [
                  ErrorLocation(line: 1, column: 1),
                ],
              ),
            ],
            context: Context()
                .withEntry(
                  ResponseExtensions(null),
                )
                .withEntry(
                  HttpLinkResponseContext(statusCode: 200),
                ),
          ),
          emitsDone,
        ]),
      );
    });

    test("throws HttpLinkServerException when status code >= 300", () async {
      final data = json.encode(<String, dynamic>{
        "data": <String, dynamic>{},
      });

      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          simpleResponse(data, 300),
        ),
      );

      HttpLinkServerException exception;

      try {
        await execute().first;
      } catch (e) {
        exception = e as HttpLinkServerException;
      }

      expect(
        exception,
        TypeMatcher<HttpLinkServerException>(),
      );
      expect(exception.response.body, data);
      expect(
        exception.parsedResponse,
        equals(
          Response(
            data: const <String, dynamic>{},
            errors: null,
            context: Context().withEntry(
              ResponseExtensions(null),
            ),
          ),
        ),
      );
    });

    test("throws HttpLinkServerException when no data and errors", () async {
      final data = json.encode(<String, dynamic>{});
      final _response = simpleResponse(data, 200);

      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          _response,
        ),
      );

      HttpLinkServerException exception;

      try {
        await execute().first;
      } catch (e) {
        exception = e as HttpLinkServerException;
      }

      expect(
        exception,
        TypeMatcher<HttpLinkServerException>(),
      );
      expect(
        exception.response.body,
        data,
      );
      expect(
        exception.parsedResponse,
        equals(
          Response(
              data: null,
              errors: null,
              context: Context().withEntry(
                ResponseExtensions(null),
              )),
        ),
      );
    });

    test("throws SerializerException when unable to serialize request",
        () async {
      final client = MockClient();
      final serializer = MockRequestSerializer();
      final link = HttpLink(
        "/graphql-test",
        httpClient: client,
        serializer: serializer,
      );

      final originalException = Exception("Foo bar");

      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          simpleResponse(
            json.encode(<String, dynamic>{
              "data": <String, dynamic>{},
            }),
            200,
          ),
        ),
      );

      when(
        serializer.serializeRequest(
          any,
        ),
      ).thenThrow(originalException);

      RequestFormatException exception;

      try {
        await link
            .request(
              Request(
                operation: Operation(
                  document: parseString("query MyQuery {}"),
                ),
                variables: const <String, dynamic>{"i": 12},
              ),
            )
            .first;
      } catch (e) {
        exception = e as RequestFormatException;
      }

      expect(
        exception,
        TypeMatcher<RequestFormatException>(),
      );
      expect(
        exception.originalException,
        originalException,
      );
    });

    test("throws ParserException when unable to serialize request", () async {
      when(
        client.send(any),
      ).thenAnswer(
        (_) => Future.value(
          simpleResponse(
            "foobar",
            200,
          ),
        ),
      );

      ResponseFormatException exception;

      try {
        await link
            .request(
              Request(
                operation: Operation(
                  document: parseString("query MyQuery {}"),
                ),
                variables: const <String, dynamic>{"i": 12},
              ),
            )
            .first;
      } catch (e) {
        exception = e as ResponseFormatException;
      }

      expect(
        exception,
        TypeMatcher<ResponseFormatException>(),
      );
      expect(
        exception.originalException,
        TypeMatcher<FormatException>(),
      );
    });

    test("closes the underlining http client", () {
      link.dispose();

      verify(
        client.close(),
      ).called(1);
    });
  });
}
