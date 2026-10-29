extends RefCounted
## Cave-only source bridge. Original global terrain shader is never edited.
const CALL:String="\n POSITION=cave_project_vertex(VERTEX,MODEL_MATRIX,VIEW_MATRIX,INV_VIEW_MATRIX,PROJECTION_MATRIX,MODELVIEW_MATRIX);\n"
const INCLUDE:String="\n#include \"res://shaders/cave_vertex_projection.gdshaderinc\"\n"
static func source(original:String)->String:
	if original.contains("cave_project_vertex("):return original
	var pattern:=RegEx.new();pattern.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{");var matches:Array[RegExMatch]=pattern.search_all(original)
	if matches.size()!=1:return ""
	var start:int=matches[0].get_end();var depth:int=1;var cursor:int=start;var end:int=-1
	while cursor<original.length():
		if original.substr(cursor,2)=="//":
			var newline:int=original.find("\n",cursor+2);cursor=original.length() if newline<0 else newline+1;continue
		if original.substr(cursor,2)=="/*":
			var close:int=original.find("*/",cursor+2)
			if close<0:return ""
			cursor=close+2;continue
		if original[cursor]=="{":depth+=1
		elif original[cursor]=="}":
			depth-=1
			if depth==0:end=cursor;break
		cursor+=1
	if end<0:return ""
	var header:int=original.find("render_mode ");var declaration:int=original.find(";",header if header>=0 else original.find("shader_type spatial"))
	if declaration<0 or declaration>=start:return ""
	return original.substr(0,declaration+1)+INCLUDE+original.substr(declaration+1,end-declaration-1)+CALL+original.substr(end)
