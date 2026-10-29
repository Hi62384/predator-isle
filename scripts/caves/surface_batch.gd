extends RefCounted
## Main-thread assembly of independently extracted surface-column groups.
## Workers receive numeric snapshots only. No partial result can be committed.
var id:int=0
var generation:int=0
var request:Dictionary={}
var groups:Array=[]
var cursor:int=0
var received:Dictionary={}
var failure:String=""
func configure(batch_id:int,revision:int,source:Dictionary)->bool:
	if source.get("columns",{}).is_empty() or source.columns.size()>64:return false
	id=batch_id;generation=revision;request=source;groups=[];cursor=0;received={};failure=""
	var columns:Array=source.columns.keys();columns.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.x<b.x or (a.x==b.x and a.y<b.y))
	for index in range(mini(4,columns.size())):groups.append({})
	for index in range(columns.size()):groups[index%groups.size()][columns[index]]=true
	return true
func pending()->bool:return failure.is_empty() and cursor<groups.size()
func take()->Dictionary:
	if not pending():return {}
	var part:int=cursor;cursor+=1;return {"batch_id":id,"generation":generation,"part":part,"columns":groups[part]}
func accept(batch_id:int,revision:int,part:int,data:Dictionary)->bool:
	if batch_id!=id or revision!=generation or part<0 or part>=groups.size() or received.has(part):return false
	if not data.get("valid",false):failure=data.get("reason","Surface column extraction failed");return false
	if data.get("owned_columns",{})!=groups[part] or data.get("columns",{})!=request.columns:failure="Surface column ownership mismatch";return false
	received[part]=data;return true
func complete()->bool:return failure.is_empty() and not groups.is_empty() and received.size()==groups.size()
func assemble()->Dictionary:
	if not complete():return {"valid":false,"reason":failure if not failure.is_empty() else "Incomplete surface batch"}
	var cells:Array=[];var keys:Dictionary={};var ground:Dictionary={}
	for index in range(groups.size()):
		var part:Dictionary=received[index]
		for data:Dictionary in part.get("cells",[]):
			if keys.has(data.key):return {"valid":false,"reason":"Duplicate extracted surface cell"}
			keys[data.key]=true;cells.append(data)
		if index==0:ground=part.get("ground",{})
	if ground.is_empty():return {"valid":false,"reason":"Missing complete original-ground subtraction"}
	cells.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.key.x<b.key.x or (a.key.x==b.key.x and (a.key.y<b.key.y or (a.key.y==b.key.y and a.key.z<b.key.z))))
	return {"valid":true,"cells":cells,"ground":ground,"columns":request.columns.duplicate()}
