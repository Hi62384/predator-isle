extends RefCounted
static func strip(source:String)->String:
	var search:int=0
	while true:
		var begin:int=source.find("if(false",search)
		if begin<0:break
		var cursor:int=begin+3;var depth:int=1
		while cursor<source.length() and depth>0:
			if source[cursor]=="(":depth+=1
			elif source[cursor]==")":depth-=1
			cursor+=1
		if depth!=0:return source
		while cursor<source.length() and source[cursor] in [" ","\n","\t","\r"]:cursor+=1
		if cursor>=source.length() or source[cursor]!="{":search=cursor;continue
		var body:int=cursor+1;cursor=body;depth=1
		while cursor<source.length() and depth>0:
			if source[cursor]=="{":depth+=1
			elif source[cursor]=="}":depth-=1
			cursor+=1
		assert(depth==0)
		source=source.substr(0,body)+source.substr(cursor-1);search=body+1
	return source
static func compact(original:String,mask:int)->String:
	var source:String=preload("res://scripts/terrain_shader_variants.gd").source_for(original,mask)
	var extensions:String=FileAccess.get_file_as_string("res://shaders/biome_extensions.gdshaderinc")
	for family:int in range(8):
		if (mask & (1<<(family+8)))==0:extensions=extensions.replace("if(family==%d){"%family,"if(false){")
	if (mask & ((1<<11)|(1<<15)))==0:extensions=extensions.replace("if(family==3 || family==7){","if(false){")
	source=source.replace('#include "res://shaders/biome_extensions.gdshaderinc"',strip(extensions))
	return strip(source)
