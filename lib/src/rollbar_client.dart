part of rollbar;

class Rollbar {
  String _accessToken;
  Map<String, Object> _config;
  Logger _logger;
  Client _client;

  Rollbar(this._accessToken, String platform, String environment, {Map<String, Object> config, Logger logger, Client client}) {
    _logger = logger != null ? logger : _defaultLogger;
    _client = client != null ? client : new IOClient();

    _config = config != null ? config : <String, Object>{};
    _config.addAll(<String, Object>{
      "platform": platform,
      "framework": platform,
      "environment": environment,
      "language": "dart",
      "notifier": {
        "name": "rollbar.dart",
        "version": "0.0.1"
      }
    });
  }

  Future<Response> trace(Object error, StackTrace stackTrace, {Map<String, Object> otherData}) {
    Map<String, Object> body = <String, Object>{
      "trace": {
        "frames": new Trace.from(stackTrace).frames.map((frame) {
          return {
            "filename": Uri.parse(frame.uri.toString()).path,
            "lineno": frame.line,
            "method": frame.member,
            "colno": frame.column
          };
        }).toList(),
        "exception": {
          "class": error.runtimeType.toString(),
          "message": error.toString()
        }
      }
    };

    Map<String, Object> data = _generatePayloadData(body, otherData);
    return new RollbarRequest(_accessToken, data, _logger, _client).send();
  }

  Future<Response> message(String messageBody, {Map<String, Object> metadata, Map<String, Object> otherData}) {
    Map<String, Object> body = <String, Object> {
      "message": {
        "body": messageBody
      }
    };

    if (metadata != null) {
      body["message"] = metadata;
    }

    Map<String, Object> data = _generatePayloadData(body, otherData);
    return new RollbarRequest(_accessToken, data, _logger, _client).send();
  }

  /// Runs [body] in its own [Zone] and reports any uncaught asynchronous or synchronous
  /// errors from the zone to Rollbar.
  ///
  /// Use [otherData] to return a map of additional data that will be attached to the
  /// payload sent to Rollbar. The returned data will attached to the payload's `data`
  /// property.
  ///
  /// The returned stream will contain futures that complete with the HTTP request for
  /// each error reported to Rollbar. The futures can be used to listen for completion
  /// or errors while calling the Rollbar API. The stream will also contain any uncaught
  /// errors originating from the zone. Use [Stream.handleError] to process these errors.
  Stream<Future<Response>> traceErrorsInZone(body(), {Map<String, Object> otherData(error, StackTrace trace)}) {
    var errors = new StreamController.broadcast();

    runZoned(body, onError: (error, stackTrace) {
      var request;

      try {
        request = trace(error, stackTrace, otherData: otherData != null ? otherData(error, stackTrace) : null);
      } catch (error, stackTrace) {
        request = trace(error, stackTrace);
      }

      errors.add(request);
      errors.addError(error, stackTrace);
    });

    return errors.stream;
  }

  Map<String, Object> _generatePayloadData(Map<String, Object> body, Map<String, Object> otherData) {
    Map<String, Object> data = <String, Object>{
      "body": body,
      "timestamp": new DateTime.now().millisecondsSinceEpoch / 1000,
      "language": "dart"
    };

    if (otherData != null) {
      data = deepMerge(data, otherData);
//      otherData.addAll(data);
    }

    return deepMerge(_config, data);
//    data.addAll(_config);
    return data;
  }
}
