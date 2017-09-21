var _user$project$Native_Http = (function() {
    var _Succeed = 0;
    var _Simple = 1;
    var _Complex = 2;
    var _AndThen = 3;

    var succeed = function(value) {
        return { type: _Succeed, value: value };
    };

    var request = function(config) {
        return {
            type: _Simple,
            config: config,
            responseToResult: config.expect._0.responseToResult,
            responseType: config.expect._0.responseType
        };
    };

    var map = function(op, request) {
        switch (request.type) {
            case _Succeed:
                return { type: _Succeed, value: op(request.value) };
            case _Simple:
                return {
                    type: _Simple,
                    config: request.config,
                    responseToResult: function(response) {
                        return A2(
                            _elm_lang$core$Result$map,
                            op,
                            request.responseToResult(response)
                        );
                    }
                };
            case _Complex:
                return {
                    type: _Complex,
                    left: request.left,
                    right: request.right,
                    combine: F2(function(left, right) {
                        return op(A2(request.combine, left, right));
                    })
                };
            case _AndThen:
                return {
                    type: _AndThen,
                    request: requestA,
                    toRequestB: function(response) {
                        return op(request.toRequestB(response));
                    }
                };
        }
    };

    var map2 = function(combine, left, right) {
        return { type: _Complex, left: left, right: right, combine: combine };
    };

    var andThen = function(toRequestB, requestA) {
        return { type: _AndThen, request: requestA, toRequestB: toRequestB };
    };

    function toResponse(xhr) {
        return {
            status: { code: xhr.status, message: xhr.statusText },
            headers: parseHeaders(xhr.getAllResponseHeaders()),
            url: xhr.responseURL,
            body: xhr.response
        };
    }

    function parseHeaders(rawHeaders) {
        var headers = _elm_lang$core$Dict$empty;

        if (!rawHeaders) {
            return headers;
        }

        var headerPairs = rawHeaders.split('\u000d\u000a');
        for (var i = headerPairs.length; i--; ) {
            var headerPair = headerPairs[i];
            var index = headerPair.indexOf('\u003a\u0020');
            if (index > 0) {
                var key = headerPair.substring(0, index);
                var value = headerPair.substring(index + 2);

                headers = A3(
                    _elm_lang$core$Dict$update,
                    key,
                    function(oldValue) {
                        if (oldValue.ctor === 'Just') {
                            return _elm_lang$core$Maybe$Just(
                                value + ', ' + oldValue._0
                            );
                        }
                        return _elm_lang$core$Maybe$Just(value);
                    },
                    headers
                );
            }
        }

        return headers;
    }

    var handleResponse = function(xhr, responseToResult, fail, finish) {
        var response = toResponse(xhr);

        if (xhr.status < 200 || 300 <= xhr.status) {
            response.body = xhr.responseText;
            return fail({
                ctor: 'BadStatus',
                _0: response
            });
        }

        var result = responseToResult(response);

        if (result.ctor === 'Ok') {
            return finish(result._0);
        } else {
            debugger;
            response.body = xhr.responseText;
            return fail({
                ctor: 'BadPayload',
                _0: result._0,
                _1: response
            });
        }
    };

    function configureRequest(xhr, request) {
        function setHeader(pair) {
            xhr.setRequestHeader(pair._0, pair._1);
        }

        A2(_elm_lang$core$List$map, setHeader, request.config.headers);
        xhr.responseType = request.responseType;
        xhr.withCredentials = request.config.withCredentials;

        if (request.config.timeout.ctor === 'Just') {
            xhr.timeout = request.config.timeout._0;
        }
    }

    function sendXHR(xhr, body) {
        switch (body.ctor) {
            case 'EmptyBody':
                xhr.send();
                return;

            case 'StringBody':
                xhr.setRequestHeader('Content-Type', body._0);
                xhr.send(body._1);
                return;

            case 'FormDataBody':
                xhr.send(body._0);
                return;
        }
    }

    var send = function(request, aborters, fail, finish) {
        switch (request.type) {
            case _Succeed:
                finish(request.value);
                break;
            case _Simple:
                var xhr = new XMLHttpRequest();

                xhr.addEventListener('error', function() {
                    fail({ ctor: 'NetworkError' });
                });

                xhr.addEventListener('load', function() {
                    handleResponse(xhr, request.responseToResult, fail, finish);
                });

                try {
                    xhr.open(request.config.method, request.config.url, true);
                } catch (e) {
                    return fail({ ctor: 'BadUrl', _0: request.config.url });
                }

                configureRequest(xhr, request);
                aborters.push(xhr.abort.bind(xhr));

                sendXHR(xhr, request.config.body);

                // configure and send request..
                break;
            case _Complex:
                var leftResult = null,
                    rightResult = null,
                    gotLeft = false,
                    gotRight = false;

                send(request.left, aborters, fail, function(result) {
                    leftResult = result;
                    gotLeft = true;

                    if (gotRight) {
                        finish(A2(request.combine, leftResult, rightResult));
                    }
                });

                send(request.right, aborters, fail, function(result) {
                    rightResult = result;
                    gotRight = true;

                    if (gotLeft) {
                        finish(A2(request.combine, leftResult, rightResult));
                    }
                });

                break;
            case _AndThen:
                send(request.request, aborters, fail, function(response) {
                    send(request.toRequestB(response), aborters, fail, finish);
                });
        }
    };

    var toTask = function(request) {
        return _elm_lang$core$Native_Scheduler.nativeBinding(function(
            callback
        ) {
            var aborters = [];
            var running = true;

            var abort = function() {
                if (!running) {
                    return;
                }

                running = false;

                for (var i = 0; i < aborters.length; i++) {
                    aborters[i]();
                }
            };

            var fail = function(reason) {
                if (running) {
                    abort();
                    callback(_elm_lang$core$Native_Scheduler.fail(reason));
                }
            };

            var finish = function(result) {
                if (!running) {
                    return;
                }

                running = false;
                callback(_elm_lang$core$Native_Scheduler.succeed(result));
            };

            send(request, aborters, fail, finish);

            return abort;
        });
    };

    return {
        succeed: succeed,
        request: request,
        map: F2(map),
        map2: F3(map2),
        toTask: toTask,
        andThen: F2(andThen)
    };
})();

/*
{ type: succeed, value: value }
{ type: simple, config: {RequestConfig} }
{ type: complex, left: request, right: request, combine: F }
*/
