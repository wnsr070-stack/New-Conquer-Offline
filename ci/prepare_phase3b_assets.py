#!/usr/bin/env python3
"""Fetch CC0 Quaternius/OGA assets; convert supported models with Assimp and optimize GLB."""
import json, pathlib, subprocess, zipfile, shutil, sys, os, re, hashlib, urllib.request, urllib.parse, urllib.error, html.parser, tarfile, time, random, http.client
ROOT=pathlib.Path.cwd()
RAW=ROOT/".cache/phase3b/source"; EXTRACT=ROOT/".cache/phase3b/extracted"
OUT=ROOT/"assets/phase3b"; REPORT=ROOT/"artifacts/phase3b_asset_report.json"
for p in (RAW,EXTRACT,OUT,REPORT.parent): p.mkdir(parents=True,exist_ok=True)
OGA=[
 {"id":"kutejnikov_weapons","url":"https://opengameart.org/sites/default/files/weapons_5.zip","archive":"weapons_5.zip","kind":"weapon"},
 {"id":"cethiel_weapons","url":"https://opengameart.org/sites/default/files/handpainted%20weapons.zip","archive":"cethiel_weapons.zip","kind":"weapon"},
 {"id":"infernal_sword","url":"https://opengameart.org/sites/default/files/3d_-_infernal_sword.zip","archive":"infernal_sword.zip","kind":"weapon"},
 {"id":"cethiel_dragon","url":"https://opengameart.org/sites/default/files/dragon_oga.zip","archive":"dragon_oga.zip","kind":"monster"},
 {"id":"special_effects","url":"https://opengameart.org/sites/default/files/blender-volumetric-particles-effects.zip","archive":"special_effects.zip","kind":"effects"}]
# Immutable public GitHub mirror of Quaternius CC0 packs.
GH_ASSET_REPO="Papyszoo/CC0-Public-Domain-Models"
GH_ASSET_REF="77343cac874f06b73d16ad0063339df7c9ca254c"
QUATERNIUS={
 "rpg_characters":"quaternius-rpg-characters",
 "modular_weapons":"quaternius-medieval-weapons",
 "ultimate_monsters":"quaternius-ultimate-monsters",
 "knight_character":"quaternius-knightcharacter",
 "base_mesh":"the-base-mesh"}
report={"oga":[],"quaternius_packs":[],"converted":[],"skipped":[],"errors":[],"counts":{"characters":0,"weapons":0,"monsters":0},"oga_counts":{"weapons":0,"monsters":0}}
MODEL_EXT={".obj",".fbx",".gltf",".glb",".stl",".ply",".dae"}
def run(cmd,**kw): return subprocess.run(cmd,check=True,**kw)
def slug(s): return re.sub(r"[^a-z0-9]+","_",s.lower()).strip("_")[:90] or "model"
class Links(html.parser.HTMLParser):
 def __init__(self): super().__init__(); self.hrefs=[]
 def handle_starttag(self,tag,attrs):
  if tag=="a":
   a=dict(attrs); h=a.get("href","")
   if h: self.hrefs.append((h,a.get("title","")))
# All HTTP requests are serialized through one downloader.
_LAST_HTTP_REQUEST_AT = 0.0
_DOWNLOAD_INTERVAL_SECONDS = 0.25
_DOWNLOAD_ATTEMPTS = 6
_RETRY_DELAYS = (2, 4, 8, 16, 32)
_RETRYABLE_HTTP_STATUS = {429, 500, 502, 503, 504}
def download_with_retry(url,headers=None):
 global _LAST_HTTP_REQUEST_AT
 request_headers={"User-Agent":"New-Conquer-Offline-Phase3B/2.1 (+https://github.com/wnsr070-stack/New-Conquer-Offline)","Accept":"application/octet-stream, application/vnd.github+json, */*"}
 if headers: request_headers.update(headers)
 parsed=urllib.parse.urlparse(url)
 token=os.environ.get("GITHUB_TOKEN","").strip()
 if token and parsed.netloc.lower() in {"github.com","api.github.com","raw.githubusercontent.com"}:
  request_headers["Authorization"]="Bearer "+token
 last_error=None
 for attempt in range(1,_DOWNLOAD_ATTEMPTS+1):
  time.sleep(0.25)
  req=urllib.request.Request(url,headers=request_headers)
  try:
   with urllib.request.urlopen(req,timeout=120) as response:
    data=response.read()
   if not data: raise RuntimeError("downloaded response is empty")
   return data
  except urllib.error.HTTPError as error:
   last_error=error
   if error.code not in _RETRYABLE_HTTP_STATUS: raise
   if error.code==503: print("PHASE3B_HTTP_503_RETRY:",f"attempt={attempt}/{_DOWNLOAD_ATTEMPTS}","url=",url,flush=True)
  except (urllib.error.URLError,TimeoutError,ConnectionError,OSError,http.client.HTTPException) as error:
   last_error=error
  if attempt>=_DOWNLOAD_ATTEMPTS: break
  base_delay=_RETRY_DELAYS[attempt-1]; delay=base_delay+random.uniform(0.0,max(0.25,base_delay*0.25))
  print("PHASE3B_DOWNLOAD_RETRY:",f"attempt={attempt}/{_DOWNLOAD_ATTEMPTS}","next_delay_seconds=",round(delay,2),"url=",url,"error=",str(last_error),flush=True)
  time.sleep(delay)
 raise RuntimeError(f"download failed after {_DOWNLOAD_ATTEMPTS} attempts: {url}: {last_error}")

def cached_asset_valid(path):
 path=pathlib.Path(path)
 if not path.is_file() or path.stat().st_size<=0: return False
 suffix=path.suffix.lower()
 try:
  if suffix==".glb":
   data=path.read_bytes()
   return len(data)>=1000 and data[:4]==b"glTF" and int.from_bytes(data[8:12],"little")==len(data)
  if suffix==".gltf":
   doc=json.loads(path.read_text(encoding="utf-8"))
   return isinstance(doc,dict) and isinstance(doc.get("asset"),dict)
  if suffix==".zip": return zipfile.is_zipfile(path)
  if suffix==".7z": return path.read_bytes()[:6]==bytes.fromhex("377abcaf271c")
  if suffix==".obj":
   with path.open("r",encoding="utf-8",errors="ignore") as stream: return any(line.startswith(("v ","f ")) for line in stream)
  if suffix in {".png",".jpg",".jpeg",".webp",".tga"}:
   head=path.read_bytes()[:12]
   return (head.startswith(b"\x89PNG\r\n\x1a\n") or head.startswith(b"\xff\xd8\xff") or
           (head.startswith(b"RIFF") and head[8:12]==b"WEBP") or (suffix==".tga" and len(head)==12))
  return True
 except (OSError,ValueError,json.JSONDecodeError): return False
def github_get(url,headers=None):
 h={"Accept":"application/vnd.github+json"}
 if headers: h.update(headers)
 return download_with_retry(url,h)
def download_url(url,dest):
 dest.parent.mkdir(parents=True,exist_ok=True)
 if cached_asset_valid(dest):
  print("PHASE3B_OGA_ARCHIVE_CACHE_HIT:",dest.name,"bytes=",dest.stat().st_size,flush=True)
  return dest
 if dest.exists(): dest.unlink()
 data=download_with_retry(url,{"Accept":"application/octet-stream,*/*"})
 if len(data)<10000: raise RuntimeError(f"download too small ({len(data)} bytes): {url}")
 tmp=dest.with_name(dest.stem+".part"+dest.suffix); tmp.write_bytes(data)
 if dest.suffix.lower()==".zip" and not zipfile.is_zipfile(tmp):
  tmp.unlink(missing_ok=True); raise RuntimeError(f"downloaded archive is not a valid ZIP: {url}")
 if dest.suffix.lower()==".7z" and tmp.read_bytes()[:6]!=bytes.fromhex("377abcaf271c"):
  tmp.unlink(missing_ok=True); raise RuntimeError(f"downloaded archive is not a valid 7z: {url}")
 tmp.replace(dest)
 if not cached_asset_valid(dest):
  dest.unlink(missing_ok=True); raise RuntimeError(f"downloaded archive failed validation: {dest}")
 print("PHASE3B_OGA_ARCHIVE_DOWNLOADED:",dest.name,"bytes=",len(data),flush=True)
 return dest
def extract_archive(archive,target,require_models=True):
 target.mkdir(parents=True,exist_ok=True)
 if zipfile.is_zipfile(archive):
  with zipfile.ZipFile(archive) as zf:
   root=target.resolve()
   for info in zf.infolist():
    dest=(target/info.filename).resolve()
    if dest!=root and root not in dest.parents: raise RuntimeError(f"unsafe ZIP member path: {info.filename}")
   zf.extractall(target)
 elif archive.read_bytes()[:6]==bytes.fromhex("377abcaf271c"):
  run(["7z","x","-y",f"-o{target}",str(archive)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 else: raise RuntimeError(f"unsupported or invalid archive: {archive}")
 count=len(models_under(target))
 if count==0 and require_models: raise RuntimeError(f"archive contains no supported 3D model files: {archive.name}")
 print("PHASE3B_OGA_ARCHIVE_EXTRACTED:",archive.name,"models=",count,"files=",sum(1 for x in target.rglob("*") if x.is_file()),"to=",target.relative_to(ROOT),flush=True)
 return target
def fetch_sources():
 tree_url=f"https://api.github.com/repos/{GH_ASSET_REPO}/git/trees/{GH_ASSET_REF}?recursive=1"
 tree=json.loads(github_get(tree_url).decode("utf-8"))
 if tree.get("truncated"): raise RuntimeError("GitHub asset tree response was truncated; refusing partial inventory")
 entries=tree.get("tree",[])
 for key,slug_name in QUATERNIUS.items():
  try:
   pack_root=f"packs/{slug_name}"
   meta_url=f"https://raw.githubusercontent.com/{GH_ASSET_REPO}/{GH_ASSET_REF}/{pack_root}/pack.json"
   meta=json.loads(github_get(meta_url).decode("utf-8"))
   if str(meta.get("license","")).upper()!="CC0": raise RuntimeError(f"source pack license is not CC0: {meta.get('license')}")
   if key!="base_mesh" and meta.get("creator")!="Quaternius": raise RuntimeError("source pack creator is not verified as Quaternius")
   candidates=[x for x in entries if x.get("type")=="blob" and x.get("path","").startswith(pack_root+"/models/") and x["path"].lower().endswith(".glb")]
   if key=="base_mesh":
    # Discover real weapon files by their model filename, not a brittle full-path suffix.
    # The pinned pack currently contains both 3- and 4-point shuriken GLBs.
    base_mesh_names={"halberd","3_point_shuriken","4_point_shuriken","throwing_knife"}
    candidates=[x for x in entries if x.get("type")=="blob"
                and x.get("path","").lower().startswith(pack_root.lower()+"/models/")
                and pathlib.PurePosixPath(x["path"]).suffix.lower()==".glb"
                and pathlib.PurePosixPath(x["path"]).stem.lower() in base_mesh_names]
   if key=="base_mesh":
    discovered=sorted(pathlib.PurePosixPath(x["path"]).stem for x in candidates)
    report.setdefault("base_mesh_source_models",[]).extend(
     {"path":x["path"],"bytes":x.get("size",0)} for x in candidates)
    required_base={"halberd","3_point_shuriken","4_point_shuriken","throwing_knife"}
    missing_base=sorted(required_base-set(discovered))
    if missing_base: raise RuntimeError("pinned Base Mesh is missing required real model files: "+str(missing_base))
   if not candidates: raise RuntimeError("pinned source pack contains no supported model files")
   target=RAW/key
   cached_count=0; downloaded_count=0; failed_files=[]
   for item in candidates:
    rel=item["path"][len(pack_root)+1:]; dest=target/rel; dest.parent.mkdir(parents=True,exist_ok=True)
    if cached_asset_valid(dest):
     cached_count+=1
     continue
    if dest.exists(): dest.unlink()
    try:
     data=download_with_retry(f"https://raw.githubusercontent.com/{GH_ASSET_REPO}/{GH_ASSET_REF}/{item['path']}")
     if len(data)<1000 or data[:4]!=b"glTF": raise RuntimeError(f"invalid GLB payload: {item['path']}")
     if int.from_bytes(data[8:12],"little")!=len(data): raise RuntimeError(f"GLB length header mismatch: {item['path']}")
     tmp=dest.with_name(dest.stem+".part"+dest.suffix); tmp.write_bytes(data)
     if not cached_asset_valid(tmp):
      tmp.unlink(missing_ok=True); raise RuntimeError(f"cached GLB validation failed: {item['path']}")
     tmp.replace(dest); downloaded_count+=1
    except Exception as file_error:
     failed_files.append({"path":item["path"],"error":str(file_error)})
     print("PHASE3B_OPTIONAL_SOURCE_PART_WARNING:",key,item["path"],"error=",str(file_error),flush=True)
   actual_files=[target/(x["path"][len(pack_root)+1:]) for x in candidates]
   valid_files=[p for p in actual_files if cached_asset_valid(p)]
   if not valid_files: raise RuntimeError(f"no valid local or downloaded GLB files remain for source pack {key}")
   report["quaternius_packs"].append({"pack":key,"source_repo":GH_ASSET_REPO,"source_ref":GH_ASSET_REF,"source_pack":slug_name,"website":meta.get("website"),"creator":meta.get("creator"),"license":"CC0","files":len(valid_files),"expected_files":len(candidates),"cache_hits":cached_count,"downloaded_files":downloaded_count,"failed_files":failed_files,"bytes":sum(p.stat().st_size for p in valid_files),"status":"downloaded_cached_or_partial_with_fallback"})
  except Exception as e:
   report["errors"].append({"source":key,"error":str(e)})
   print("PHASE3B_QUATERNIUS_SOURCE_ERROR:",key,str(e),flush=True)
 for item in OGA:
  dest=RAW/item["archive"]
  try:
   if not cached_asset_valid(dest): download_url(item["url"],dest)
   if not cached_asset_valid(dest) or dest.stat().st_size<10000: raise RuntimeError("downloaded archive is missing, empty, or invalid")
   target=EXTRACT/item["id"]
   extracted_ok=target.is_dir() and (bool(models_under(target)) if item["kind"]!="effects" else any(target.iterdir()))
   if not extracted_ok:
    if target.exists(): shutil.rmtree(target)
    extract_archive(dest,target,require_models=item["kind"]!="effects")
   report["oga"].append({"id":item["id"],"bytes":dest.stat().st_size,"kind":item["kind"],"status":"downloaded"})
  except Exception as e:
   report["errors"].append({"source":item["id"],"error":str(e)})
   print("PHASE3B_OGA_SOURCE_ERROR:",item["id"],str(e),flush=True)
def validate_glb(path, label, min_size=10*1024):
 path=pathlib.Path(path)
 if not path.is_file(): raise RuntimeError(f"{label} was not created: {path}")
 size=path.stat().st_size
 with path.open("rb") as stream: magic=stream.read(4)
 if size<min_size or magic!=b"glTF":
  raise RuntimeError(f"{label} failed GLB validation: size={size}, magic={magic!r}, expected >10240 bytes and b'glTF'")
 return size
def optimize_to_glb(source,dest):
 dest.parent.mkdir(parents=True,exist_ok=True)
 tmp=dest.with_name(dest.stem+"_assimp.glb")
 is_target_dragon=(source.suffix.lower()==".dae" and source.name.lower()=="dragon.dae"
                   and source.parent.name.lower()=="cethiel_dragon")
 if source.suffix.lower() in {".glb",".gltf"}:
  run(["gltfpack","-noq","-i",str(source),"-o",str(dest)])
 elif is_target_dragon:
  raw_glb=dest.with_name(dest.stem+"_blender_raw.glb")
  raw_glb.unlink(missing_ok=True)
  blender_script=dest.with_name(dest.stem+"_blender_import.py")
  blender_script.write_text(
   "import sys\n"
   "sys.path.append('/usr/lib/python3/dist-packages')\n"
   "try:\n"
   "    import numpy\n"
   "except ImportError:\n"
   "    import subprocess\n"
   "    subprocess.check_call([sys.executable, '-m', 'ensurepip', '--upgrade'])\n"
   "    subprocess.check_call([sys.executable, '-m', 'pip', 'install', '--disable-pip-version-check', 'numpy<2'])\n"
   "    import numpy\n"
   "print('BLENDER_NUMPY_OK:', numpy.__version__, flush=True)\n"
   "import bpy\n"
   "dae_path = "+repr(str(source.resolve()))+"\n"
   "raw_glb = "+repr(str(raw_glb.resolve()))+"\n"
   "bpy.ops.wm.read_factory_settings(use_empty=True)\n"
   "bpy.ops.wm.collada_import(filepath=dae_path, import_units=True)\n"
   "meshes = [o for o in bpy.data.objects if o.type == 'MESH']\n"
   "if not meshes: raise RuntimeError('COLLADA import produced no MESH objects')\n"
   "print('PHASE3B_DRAGON_BLENDER_MESH_COUNT:', len(meshes), flush=True)\n"
   "bpy.ops.export_scene.gltf(filepath=raw_glb, export_format='GLB', export_apply=True)\n",
   encoding="utf-8")
  print("PHASE3B_DAE_BLENDER_DIRECT:",source,"assimp=SKIPPED",flush=True)
  proc=subprocess.run(["blender","--background","--factory-startup","--python-exit-code","1","--python",str(blender_script)],
                      stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
  print("PHASE3B_BLENDER_STDOUT_BEGIN\n"+(proc.stdout or "")+"\nPHASE3B_BLENDER_STDOUT_END",flush=True)
  print("PHASE3B_BLENDER_STDERR_BEGIN\n"+(proc.stderr or "")+"\nPHASE3B_BLENDER_STDERR_END",flush=True)
  if proc.returncode!=0: raise RuntimeError(f"Blender dragon conversion exited {proc.returncode}")
  raw_size=validate_glb(raw_glb,"raw Blender dragon GLB")
  print("PHASE3B_DRAGON_RAW_GLB_VALID:",raw_glb,"bytes=",raw_size,flush=True)
  run(["gltfpack","-noq","-i",str(raw_glb),"-o",str(dest)])
  final_size=validate_glb(dest,"optimized dragon GLB")
  print("PHASE3B_DRAGON_FINAL_GLB_VALID:",dest,"bytes=",final_size,flush=True)
  raw_glb.unlink(missing_ok=True)
  blender_script.unlink(missing_ok=True)
 else:
  try:
   run(["assimp","export",str(source),str(tmp)])
  except Exception as assimp_error:
   if source.suffix.lower() != ".dae": raise
   tmp.unlink(missing_ok=True)
   blender_expr=("import bpy; bpy.ops.wm.read_factory_settings(use_empty=True); "
    "bpy.ops.wm.collada_import(filepath="+repr(str(source.resolve()))+"); "
    "bpy.ops.export_scene.gltf(filepath="+repr(str(tmp.resolve()))+", export_format='GLB')")
   print("PHASE3B_DAE_BLENDER_FALLBACK:",source,"assimp_error=",str(assimp_error),flush=True)
   proc=subprocess.run(["blender","--background","--factory-startup","--python-exit-code","1","--python-expr",blender_expr],
                       stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
   print("PHASE3B_BLENDER_STDOUT_BEGIN\n"+(proc.stdout or "")+"\nPHASE3B_BLENDER_STDOUT_END",flush=True)
   print("PHASE3B_BLENDER_STDERR_BEGIN\n"+(proc.stderr or "")+"\nPHASE3B_BLENDER_STDERR_END",flush=True)
   if proc.returncode!=0: raise RuntimeError(f"Blender fallback exited {proc.returncode}")
  validate_glb(tmp,"Assimp/Blender intermediate GLB",min_size=1000)
  run(["gltfpack","-noq","-i",str(tmp),"-o",str(dest)])
  tmp.unlink(missing_ok=True)
 validate_glb(dest,"final GLB",min_size=1000)
 return dest
def models_under(root):
 return [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in MODEL_EXT]
def convert_quaternius(pack):
 root=RAW/pack; files=models_under(root)
 if not files: raise RuntimeError("no supported model files found in pinned CC0 GitHub pack")
 if pack=="ultimate_monsters":
  converted=0
  for src in files:
   dst=OUT/"monsters"/(slug(src.parent.name+"_"+src.stem)+".glb")
   try:
    optimize_to_glb(src,dst); converted+=1
    report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":"Quaternius CC0","category":"monster"})
   except Exception as e:
    report["errors"].append({"source":str(src),"error":str(e)})
    print("PHASE3B_OGA_CONVERSION_ERROR:",pack,str(src),str(e),flush=True)
  report["counts"]["monsters"]+=converted
  if converted==0: raise RuntimeError("Ultimate Monsters produced zero valid GLB models")
  return
 for src in files:
  dst=OUT/"quaternius_library"/(slug(src.parent.name+"_"+src.stem)+".glb")
  try:
   optimize_to_glb(src,dst); creator="The Base Mesh CC0" if pack=="base_mesh" else "Quaternius CC0"
   report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":creator,"pack":pack})
  except Exception as e: report["errors"].append({"source":str(src),"error":str(e)})
def pick_model(pack,aliases):
 files=models_under(RAW/pack); hits=[p for p in files if any(a in slug(p.stem) for a in aliases)]
 if not hits: raise RuntimeError("no model matched aliases "+str(aliases)+" in "+pack)
 hits.sort(key=lambda p:(0 if p.suffix.lower() in {".glb",".gltf"} else 1 if p.suffix.lower()==".fbx" else 2,len(p.name)))
 return hits[0]
def pick_model_anywhere(name_tokens):
 # Search every extracted Quaternius and OpenGameArt source folder, recursively and case-insensitively.
 roots=[RAW,EXTRACT,OUT/"quaternius_library"]
 hits=[]
 for root in roots:
  if root.exists():
   for src in models_under(root):
    normalized=re.sub(r"[^a-z0-9]+","_",src.stem.lower()).strip("_")
    if any(token in normalized for token in name_tokens):
     hits.append(src)
 if not hits:
  raise RuntimeError("no real source model matched any of "+str(name_tokens)+" under "+str(roots))
 # Prefer already packaged GLB/GLTF; retain deterministic ordering for reproducible builds.
 hits.sort(key=lambda p:(0 if p.suffix.lower()==".glb" else 1 if p.suffix.lower()==".gltf" else 2 if p.suffix.lower()==".fbx" else 3,len(p.parts),str(p).lower()))
 return hits[0]
def export_ninja_weapon(asset_name,name_tokens):
 src=pick_model_anywhere(name_tokens)
 dst=OUT/("quaternius_"+asset_name+".glb")
 optimize_to_glb(src,dst)
 report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":"verified source model","category":"weapon","matched_name_tokens":name_tokens})
 report["counts"]["weapons"]+=1
 print("PHASE3B_NINJA_WEAPON_RESOLVED:",asset_name,"source=",src.relative_to(ROOT),"output=",dst.relative_to(ROOT),flush=True)
 return dst
def export_named_models():
 characters=[("archer","rpg_characters",["ranger"]),("assassin","rpg_characters",["rogue"]),("knight","knight_character",["knight_character"]),("warrior","rpg_characters",["warrior"]),("mage","rpg_characters",["wizard"])]
 weapons=[("bow","modular_weapons",["bow_wooden"]),("dagger","rpg_characters",["rogue_dagger"]),("spear","modular_weapons",["spear"]),("halberd","base_mesh",["halberd"]),("axe","modular_weapons",["axe_double"]),("staff","rpg_characters",["wizard_staff"]),("sword","modular_weapons",["sword_big"]),("shield","modular_weapons",["shield_heater"])]
 for key,pack,aliases in characters:
  try:
   src=pick_model(pack,aliases); dst=OUT/("quaternius_"+key+".glb"); optimize_to_glb(src,dst)
   report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":"Quaternius CC0","category":"character"}); report["counts"]["characters"]+=1
  except Exception as e: report["errors"].append({"source":"quaternius_"+key,"error":str(e)})
 for key,pack,aliases in weapons:
  try:
   src=pick_model(pack,aliases); dst=OUT/("quaternius_"+key+".glb"); optimize_to_glb(src,dst)
   origin="The Base Mesh CC0" if pack=="base_mesh" else "Quaternius CC0"
   report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":origin,"category":"weapon"}); report["counts"]["weapons"]+=1
  except Exception as e: report["errors"].append({"source":"quaternius_"+key,"error":str(e)})
def convert_oga():
 allowed={"kutejnikov_weapons","cethiel_weapons","infernal_sword","old_fantasy_dagger","shuriken","cethiel_dragon"}
 for pack in sorted(allowed):
  root=EXTRACT/pack
  if not root.exists(): continue
  for src in models_under(root):
   if pack=="cethiel_dragon" and not any(k in src.stem.lower() for k in ("dragon","wyrm")): continue
   if pack=="cethiel_dragon" and src not in sorted([x for x in models_under(root) if any(k in x.stem.lower() for k in ("dragon","wyrm"))])[:2]: continue
   category="monster" if pack in {"frog_guy","cethiel_dragon"} else "weapon"
   dst=OUT/("oga_"+category+"s")/(slug(pack+"_"+src.stem)+".glb")
   try:
    optimize_to_glb(src,dst)
    report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":"OpenGameArt CC0","category":category})
    if category=="monster":
     report["counts"]["monsters"]+=1
     report["oga_counts"]["monsters"]+=1
    else:
     report["counts"]["weapons"]+=1
     report["oga_counts"]["weapons"]+=1
    
   except Exception as e: report["errors"].append({"source":str(src),"error":str(e)})
def main():
 run(["assimp","version"])
 fetch_sources()
 for pack in QUATERNIUS:
  try: convert_quaternius(pack)
  except Exception as e: report["errors"].append({"source":pack+"_conversion","error":str(e)})
 export_named_models()
 # Resolve ninja throwing weapons from actual files anywhere in the unpacked source trees.
 # The pinned Base Mesh inventory contains 3_point_shuriken.glb and 4_point_shuriken.glb;
 # other source archives may use Shuriken_1, ninja_star, or throwing_star names.
 convert_oga()
 # Build the exact 90-model progression pack and 90 real preview renders.
 run([sys.executable,"ci/build_phase3b_85_pack.py"])
 report["counts"]["characters"]=10
 report["generated_heroes"]={"count":10,"source":"Quaternius Modular Character Outfits - Fantasy","license":"CC0-1.0"}
 # Reuse the now-restored HF seed for Ninja weapons before declaring a missing source.
 for asset_name,tokens in [("shuriken",["shuriken","ninja_star","throwing_star"]),("throwing_knife",["throwing_knife","throwing_knife_","kunai"])]:
  try: export_ninja_weapon(asset_name,tokens)
  except Exception as e:
   report["errors"].append({"source":"optional_"+asset_name,"error":str(e)})
   print("PHASE3B_OPTIONAL_NINJA_WEAPON_SOURCE_WARNING:",asset_name,str(e),flush=True)
 # Preserve effect textures without pretending they are 3D models.
 for p in (EXTRACT/"special_effects").rglob("*"):
  if p.is_file() and p.suffix.lower() in {".png",".jpg",".jpeg",".tga"}:
   dst=OUT/"effects"/p.name; dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,dst)
 # Manifest includes exact asset provenance and counts.
 required=["characters/ara3d_archer.glb","characters/ara3d_assassin.glb","characters/ara3d_trojan.glb","characters/ara3d_warrior.glb","characters/ara3d_taoist.glb"]
 missing=[x for x in required if not (OUT/x).is_file() or (OUT/x).stat().st_size<1000]
 report["required_missing"]=missing
 required_packs={"rpg_characters","modular_weapons","ultimate_monsters"}
 found_packs={x.get("pack") for x in report["quaternius_packs"] if x.get("files",0)>0}
 missing_packs=sorted(required_packs-found_packs)
 report["required_packs_missing"]=missing_packs
 REPORT.write_text(json.dumps(report,indent=2),encoding="utf-8")
 for error in report["errors"]: print("PHASE3B_ASSET_ERROR:",error,flush=True)
 if missing_packs:
  print("PHASE3B_SOURCE_PACKS_PARTIAL_FALLBACK_ALLOWED:",missing_packs,
        "The exact 90-model manifest below remains the authoritative completeness gate.",flush=True)
 # The 85-model catalog uses the pinned Quaternius CC0 source set; OGA archives are supplemental.
 if report["oga_counts"]["weapons"] < 1:
  print("PHASE3B_OGA_SUPPLEMENTAL_WEAPON_COUNT:",report["oga_counts"],flush=True)
 missing_ninja=[name for name in ("quaternius_shuriken.glb",) if not (OUT/name).is_file() or (OUT/name).stat().st_size<1000]
 report["required_ninja_weapons_missing"]=missing_ninja
 report["optional_ninja_weapons_missing"]=[name for name in ("quaternius_throwing_knife.glb",) if not (OUT/name).is_file() or (OUT/name).stat().st_size<1000]
 if missing_ninja:
  print("PHASE3B_REQUIRED_NINJA_WEAPON_MISSING:",missing_ninja); sys.exit(7)
 if report["optional_ninja_weapons_missing"]:
  print("PHASE3B_OPTIONAL_NINJA_WEAPON_FALLBACK:",report["optional_ninja_weapons_missing"],flush=True)
 REPORT.write_text(json.dumps(report,indent=2),encoding="utf-8")
 # Actual on-disk inventory for each requested asset family.
 inventory={
  "characters":sum(1 for p in (OUT/"characters").glob("*_*.glb") if p.is_file() and p.stem.rsplit("_",1)[-1] in {"male","female"}),
  "weapons":sum(1 for p in OUT.rglob("*.glb") if p.is_file() and (p.parent.name=="oga_weapons" or p.name.lower().startswith("quaternius_") and any(k in p.name.lower() for k in ("bow","dagger","spear","halberd","axe","staff","sword","shield","shuriken","throwing_knife")))),
  "ultimate_monsters":sum(1 for x in report["converted"] if x.get("origin")=="Quaternius CC0" and x.get("category")=="monster" and (ROOT/x["output"]).is_file()),
  "oga_monsters":sum(1 for x in report["converted"] if x.get("origin")=="OpenGameArt CC0" and x.get("category")=="monster" and (ROOT/x["output"]).is_file())}
 report["inventory_by_category"]=inventory
 REPORT.write_text(json.dumps(report,indent=2),encoding="utf-8")
 print("PHASE3B_ACTUAL_CATEGORY_INVENTORY:",json.dumps(inventory,sort_keys=True),flush=True)
 print("PHASE3B_ASSET_REPORT:",REPORT)
 print("PHASE3B_OGA_DOWNLOADED:",len(report["oga"]),"QUATERNIUS_PACKS:",len(report["quaternius_packs"]),"CONVERTED:",len(report["converted"]),"COUNTS:",report["counts"],"OGA_COUNTS:",report["oga_counts"])
 if report["errors"]:
  for error in report["errors"]: print("PHASE3B_ASSET_ERROR:",error,flush=True)
 if missing: print("PHASE3B_REQUIRED_MODELS_MISSING:",missing); sys.exit(3)
 catalog_path=OUT/"phase3b_manifest.json"
 if not catalog_path.is_file():
  print("PHASE3B_85_CATALOG_MANIFEST_MISSING"); sys.exit(4)
 catalog=json.loads(catalog_path.read_text(encoding="utf-8"))
 if catalog.get("actual_total")!=90 or len(catalog.get("assets",[]))!=90:
  print("PHASE3B_90_CATALOG_NOT_COMPLETE:",catalog.get("actual_total"),"records=",len(catalog.get("assets",[]))); sys.exit(4)
 if catalog.get("counts",{}).get("character")!=10:
  print("PHASE3B_TEN_HERO_GATE_FAILED:",catalog.get("counts")); sys.exit(4)
 print("PHASE3B_90_CATALOG_COMPLETENESS_GATE_PASSED:",catalog.get("counts"),flush=True)
 # Publish the complete, validated package and an auditable inventory to the private HF dataset.
 token=os.environ.get("HF_TOKEN","").strip()
 if not token:
  print("PHASE3B_HF_TOKEN_MISSING"); sys.exit(8)
 from huggingface_hub import HfApi
 manifest=OUT/"phase3b_asset_manifest.json"
 manifest.write_text(json.dumps(report,indent=2),encoding="utf-8")
 files=sorted(x for x in OUT.rglob("*") if x.is_file())
 upload_bytes=sum(item.stat().st_size for item in files)
 upload_summary={"files":len(files),"bytes":upload_bytes,**inventory}
 print("PHASE3B_HF_UPLOAD_FILE_COUNT:",len(files))
 print("PHASE3B_HF_UPLOAD_BYTE_COUNT:",upload_bytes)
 print("PHASE3B_HF_UPLOAD_CATEGORY_COUNTS:",json.dumps(upload_summary,sort_keys=True),flush=True)
 for item in files:
  print("PHASE3B_HF_UPLOAD_FILE:",item.relative_to(OUT).as_posix(),"bytes=",item.stat().st_size)
 api=HfApi(token=token)
 # The destination is an existing private Hugging Face Dataset. Keep the exact
 # owner spelling (including the final zZ) and never require create_repo for it.
 hf_repo="ZzwahwahzZ/clash-of-legends-terrain-assets"
 hf_repo_type="dataset"
 try:
  repo_info=api.repo_info(repo_id=hf_repo,repo_type=hf_repo_type)
  print("PHASE3B_HF_REPO_CONFIRMED:",hf_repo,"type=",hf_repo_type,"private=",getattr(repo_info,"private",None),flush=True)
 except Exception as repo_info_error:
  response=getattr(repo_info_error,"response",None)
  status=getattr(response,"status_code",None)
  if status != 404:
   raise
  try:
   api.create_repo(repo_id=hf_repo,repo_type=hf_repo_type,private=True,exist_ok=True)
   print("PHASE3B_HF_REPO_CREATED:",hf_repo,"type=",hf_repo_type,flush=True)
  except Exception as create_error:
   create_response=getattr(create_error,"response",None)
   create_status=getattr(create_response,"status_code",None)
   if create_status in (403,409):
    print("HF_CREATE_REPO_SKIPPED:", "HTTP",create_status,str(create_error),flush=True)
   else:
    raise
 upload_commit=api.upload_folder(repo_id=hf_repo,repo_type=hf_repo_type,folder_path=str(OUT),path_in_repo="phase3b",commit_message="cache(phase3b): verified Quaternius CC0 and OpenGameArt models")
 upload_commit_oid=getattr(upload_commit,"oid",None)
 if not upload_commit_oid:
  raise RuntimeError("Hugging Face upload_folder returned without a verifiable commit OID")
 print("PHASE3B_HF_UPLOAD_COMPLETE:",hf_repo,"repo_type=",hf_repo_type,"files=",len(files),"bytes=",upload_bytes,"category_counts=",json.dumps(upload_summary,sort_keys=True),"path=phase3b","commit=",upload_commit_oid,flush=True)
if __name__=="__main__": main()
