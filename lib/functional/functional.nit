module functional
class Unit
end
interface ConstFn[RESULT]
	fun call: RESULT is abstract
end
interface Func1[A0,RESULT]
	fun call(a0: A0):RESULT is abstract
end
interface Func2[A0,A1,RESULT]
	fun call(a0: A0,a1: A1):RESULT is abstract
end
interface Func3[A0,A1,A2,RESULT]
	fun call(a0: A0,a1: A1,a2: A2):RESULT is abstract
end
interface Func4[A0,A1,A2,A3,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3):RESULT is abstract
end
interface Func5[A0,A1,A2,A3,A4,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4):RESULT is abstract
end
interface Func6[A0,A1,A2,A3,A4,A5,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5):RESULT is abstract
end
interface Func7[A0,A1,A2,A3,A4,A5,A6,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6):RESULT is abstract
end
interface Func8[A0,A1,A2,A3,A4,A5,A6,A7,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7):RESULT is abstract
end
interface Func9[A0,A1,A2,A3,A4,A5,A6,A7,A8,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8):RESULT is abstract
end
interface Func10[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9):RESULT is abstract
end
interface Func11[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10):RESULT is abstract
end
interface Func12[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11):RESULT is abstract
end
interface Func13[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12):RESULT is abstract
end
interface Func14[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13):RESULT is abstract
end
interface Func15[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14):RESULT is abstract
end
interface Func16[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14,a15: A15):RESULT is abstract
end
interface Func17[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14,a15: A15,a16: A16):RESULT is abstract
end
interface Func18[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14,a15: A15,a16: A16,a17: A17):RESULT is abstract
end
interface Func19[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17,A18,RESULT]
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14,a15: A15,a16: A16,a17: A17,a18: A18):RESULT is abstract
end