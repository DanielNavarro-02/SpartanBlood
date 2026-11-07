class_name Onda
extends RefCounted

static func k(longitud: float) -> float:
	return TAU / longitud

static func w(periodo: float) -> float:
	return TAU / periodo

static func altura(x: float, t: float, amplitud: float, longitud: float, periodo: float) -> float:
	return amplitud * sin(k(longitud) * x - w(periodo) * t)
