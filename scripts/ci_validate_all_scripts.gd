extends SceneTree

var failures: Array[String] = []
var checked: int = 0

func _initialize() -> void:
 call_deferred("_validate_all_scripts")

func _validate_all_scripts() -> void:
 _scan_directory("res://scripts")
 if failures.is_empty():
  print("GODOT_GDSCRIPT_SYNTAX_GATE_PASS=true checked=",checked)
  quit(0)
 else:
  for failure in failures:
   push_error("GODOT_GDSCRIPT_SYNTAX_GATE_FAIL: "+failure)
  quit(1)

func _scan_directory(directory_path: String) -> void:
 var directory:=DirAccess.open(directory_path)
 if directory==null:
  failures.append("Cannot open directory: "+directory_path)
  return
 directory.list_dir_begin()
 var entry:=directory.get_next()
 while not entry.is_empty():
  if entry=="." or entry=="..":
   entry=directory.get_next()
   continue
  var path:=directory_path.path_join(entry)
  if directory.current_is_dir():
   _scan_directory(path)
  elif entry.get_extension().to_lower()=="gd":
   checked+=1
   var resource:=ResourceLoader.load(path)
   if resource==null or not (resource is GDScript):
    failures.append(path)
   else:
    print("GODOT_GDSCRIPT_SYNTAX_OK: ",path)
  entry=directory.get_next()
 directory.list_dir_end()
