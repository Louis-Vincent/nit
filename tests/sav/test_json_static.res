# Json: {"__kind": "obj", "__id": 0, "__class": "C", "a": {"__kind": "obj", "__id": 1, "__class": "A", "b": true, "c": "a", "f": 0.123, "i": 1234, "s": "asdf", "n": null, "array": [88, "hello", null]}, "b": {"__kind": "obj", "__id": 2, "__class": "B", "b": false, "c": "b", "f": 123.123, "i": 2345, "s": "hjkl", "n": null, "array": [88, "hello", null], "ii": 1111, "ss": "qwer"}, "aa": {"__kind": "ref", "__id": 1}}
# Nit: <HashMap __kind: obj, __id: 0, __class: C, a: <HashMap __kind: obj, __id: 1, __class: A, b: true, c: a, f: 0.123, i: 1234, s: asdf, n: <null>, array: [88,hello,]>, b: <HashMap __kind: obj, __id: 2, __class: B, b: false, c: b, f: 123.123, i: 2345, s: hjkl, n: <null>, array: [88,hello,], ii: 1111, ss: qwer>, aa: <HashMap __kind: ref, __id: 1>>
# Json: {"__kind": "obj", "__id": 0, "__class": "A", "b": true, "c": "a", "f": 0.123, "i": 1234, "s": "asdf", "n": null, "array": [88, "hello", null]}
# Nit: <HashMap __kind: obj, __id: 0, __class: A, b: true, c: a, f: 0.123, i: 1234, s: asdf, n: <null>, array: [88,hello,]>
# Json: {"foo":"bar\"\\\/\b\f\n\r\t\u0020\u0000"}
# Nit: <HashMap foo: bar"\/f
	  >
# Json: { "face with tears of joy" : "\uD83D\uDE02" }
# Nit: <HashMap face with tears of joy: 😂>
