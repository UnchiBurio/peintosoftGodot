# RatioConverter.gd
class_name RatioConverter
extends RefCounted

# 浮動小数点の比率を整数比に変換するユーティリティクラス
static func to_integer_ratio(ratio: float, max_denominator: int = 100) -> Dictionary:
	var best_error = ratio
	var best_a = 1
	var best_b = 1
	
	# より正確な比率を見つけるためにループ
	for b in range(1, max_denominator + 1):
		var a = round(ratio * b)
		var error = abs(ratio - (a / float(b)))
		
		if error < best_error:
			best_error = error
			best_a = a
			best_b = b
			
			# 十分な精度が得られた場合は早期終了
			if error < 0.000001:
				break
	
	# 最大公約数で約分
	var gcd = _gcd(best_a, best_b)
	return {
		"numerator": best_a / gcd,
		"denominator": best_b / gcd
	}

# 最大公約数を計算
static func _gcd(a: int, b: int) -> int:
	a = abs(a)
	b = abs(b)
	while b:
		var t = b
		b = a % b
		a = t
	return a
