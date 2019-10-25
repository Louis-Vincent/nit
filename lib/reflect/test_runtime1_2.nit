module test_runtime1_2 is test

import runtime

class Bataille
        var nom: String
        var annee: String
        var decisive: Bool

        redef fun to_s
        do
                return "{nom}, {annee}, {decisive}"
        end
end

class Annee
	var annee: Int
	var is_ac: Bool

	redef fun to_s
	do
		var ac = if is_ac then "AC" else "BC"
		return "{annee} {ac}"
	end
end

redef class String
	fun to_b: Bool do return self == "true"
end

class TestRuntime1_2
	test

	fun csv_data: String
	do
		var csv = """
Massacre à Durlieu, 302 AC, true
Bataille de Chateau Noir, 301 AC, true
Bataille de Qohor, 100 BC, true
Bataille de Ironrath, 301 AC, false
"""
		return csv
	end

	fun test_csv_init is test do
		var t_bataille = t"Bataille"
		assert t_bataille isa Type
		var res = new Array[Bataille]
		for line in csv_data.split("\n") do
			var cols = line.split(",")
			var annee_s = cols[1].split(" ")
			var a1 = cols[0]
			var a2 = new Annee(annee_s[0].to_i, annee_s[1])
			var a3 = cols[2].to_b
			var b1 = t_bataille.new_instance([a1,a2,a3]).as(Bataille)
			res.add(b1)
		end
		assert res[0].nom == "Massacre à Durlieu"
		assert res[0].annee.annee == 302
		assert res[0].annee.is_ac
		assert res[0].decisive

		assert res[1].nom == "Bataille de Chateau Noir"
		assert res[1].annee.annee == 301
		assert res[1].annee.is_ac
		assert res[1].decisive

		assert res[2].nom == "Bataille de Qohor"
		assert res[2].annee.annee == 100
		assert not res[2].annee.is_ac
		assert res[2].decisive

		assert res[3].nom == "Bataille de Ironrath"
		assert res[3].annee.annee == 301
		assert res[3].annee.is_ac
		assert not res[3].decisive
	end
end
