@tool
extends Resource
## Four independent controls. Percentages are preferences,not volume coverage.
@export var biome_id:StringName=&"default"
@export var display_name:String="Default Cave"
@export var enabled:bool=true
@export_range(0,100,.1) var spawn_chance_percent:float=100
## Definitions above1536m opt into a bounded5x5 discovery halo,not new jobs.
@export_range(50,2048,1) var minimum_extent_metres:float=200
@export_range(50,2048,1) var maximum_extent_metres:float=1200
@export var depth_preferences:PackedFloat32Array=PackedFloat32Array([100,85,65,40,15])
## Empty means all CURRENT surface owners equally suitable. Unknown names
## remain dormant;they never create/reactivate an absent surface biome.
@export var surface_preferences:Dictionary={}
@export var geological_preferences:Dictionary={}
@export_range(1,128,1) var transition_metres:float=32
@export_range(-8,8,1) var selection_priority:int=0
## Optional independent product probability:spawn*depth*surface*geology*env.
## Priority controls legacy competition only,never this probability. Defaults
## retain the complete old Default/Frozen lottery and random channels.
@export var independent_suitability_admission:bool=false
@export var material_configuration:Dictionary={"palette":"default_geology"}
@export var geometry_variation:Dictionary={}
@export var feature_configuration:Dictionary={}
## Optional numeric generator and main-thread material/source adapter. A new
## biome adds its own definition/providers,not a new cave engine or owner ID.
@export var surface_provider:Script
@export var feature_provider:Script
@export var debug_color:Color=Color(.55,.42,.27)
## Optional existing environment providers may supply these named channels.
## Without such providers no temperature/groundwater simulation is invented.
@export var temperature_channel:StringName=&""
@export var moisture_channel:StringName=&""
func validation_errors()->Array[String]:
	var errors:Array[String]=[]
	if biome_id.is_empty() or display_name.is_empty():errors.append("Cave biome requires a stable ID and display name")
	for value:float in [spawn_chance_percent,minimum_extent_metres,maximum_extent_metres,transition_metres]:
		if not is_finite(value):errors.append("Cave biome controls must be finite");return errors
	if spawn_chance_percent<0 or spawn_chance_percent>100:errors.append("Spawn chance must be0–100percent")
	if minimum_extent_metres<50 or maximum_extent_metres<minimum_extent_metres or maximum_extent_metres>2048:errors.append("Biome extent must be ordered within50–2048m bounded canonical discovery")
	if transition_metres<1 or transition_metres>128 or transition_metres>minimum_extent_metres*.5:errors.append("Transition must fit within half the smallest region")
	if depth_preferences.size()!=5:errors.append("Exactly five depth preferences are required")
	for value:float in depth_preferences:
		if not is_finite(value) or value<0 or value>100:errors.append("Depth preferences must be finite0–100")
	for preferences:Dictionary in [surface_preferences,geological_preferences]:
		for value in preferences.values():
			if not (value is float or value is int) or not is_finite(float(value)) or float(value)<0 or float(value)>100:errors.append("Suitability preferences must be finite0–100")
	for key in surface_preferences:
		if not (key is String or key is StringName):errors.append("Surface preferences use stable biome names,not numeric owner indices")
	if selection_priority< -8 or selection_priority>8:errors.append("Selection priority must be within-8–8")
	for provider:Script in [surface_provider,feature_provider]:
		if provider!=null and (not provider.can_instantiate() or provider.get_instance_base_type()!="RefCounted"):
			errors.append("Cave providers must instantiate numeric RefCounted adapters,not scene nodes");return errors
	if surface_provider!=null:
		var methods:Dictionary={}
		for method:Dictionary in surface_provider.get_script_method_list():methods[str(method.name)]=true
		if not methods.has("source") or not methods.has("bind"):errors.append("Cave surface provider requires source and bind methods")
		elif methods.has("validation_errors"):errors.append_array(surface_provider.new().validation_errors(material_configuration,feature_configuration))
	if feature_provider!=null:
		var found:bool=false
		for method:Dictionary in feature_provider.get_script_method_list():
			if str(method.name)=="build":found=true
		if not found:errors.append("Cave numeric feature provider requires build method")
	return errors
static func preference(preferences:Dictionary,mix:Dictionary)->float:
	if preferences.is_empty():return 1.0
	var maximum:float=0
	for value in preferences.values():maximum=maxf(maximum,float(value))
	if maximum<=0:return 0.0
	var result:float=0;var total:float=0
	for key in mix:
		var weight:float=maxf(0,float(mix[key]));result+=weight*float(preferences.get(key,preferences.get(str(key),0)))/maximum;total+=weight
	return clampf(result/total,0,1) if total>0 else 0.0
func depth_preference(depth:float,bands:PackedFloat32Array)->float:
	if depth_preferences.size()!=5 or bands.size()!=6 or not is_finite(depth):return 0.0
	var maximum:float=0
	for value:float in depth_preferences:maximum=maxf(maximum,value)
	if maximum<=0:return 0.0
	var anchors:=PackedFloat32Array()
	for i in range(5):anchors.append((bands[i]+bands[i+1])*.5)
	if depth<=anchors[0]:return depth_preferences[0]/maximum
	for i in range(4):
		if depth>anchors[i+1]:continue
		var t:float=smoothstep(anchors[i],anchors[i+1],depth);return lerpf(depth_preferences[i],depth_preferences[i+1],t)/maximum
	return depth_preferences[4]/maximum
