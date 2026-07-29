"""로컬 zip 에서 3D 에셋을 꺼내 프로젝트에 설치한다.

    python tools/install_3d_assets.py                 # ~/Downloads 의 에셋 zip 자동 탐색
    python tools/install_3d_assets.py a.zip b.zip     # 지정한 것만

**인터넷에서 내려받지는 않는다.** 자동 다운로드는 이 환경에서 불가능해서,
받아 둔 zip 을 넣기만 하면 되게 만들었다.

받을 곳 (전부 CC0 · 상업 이용 가능)
  건축/던전   https://kenney.nl/assets/modular-dungeon-kit
  자연/폐허   https://kenney.nl/assets/nature-kit
  무기        https://quaternius.com/packs/medievalweapons.html
  몬스터      https://quaternius.com/packs/ultimatemonsters.html
  애니메이션  https://quaternius.com/packs/universalanimationlibrary.html

Godot 가 읽는 형식만 골라 복사한다.
  1순위 .glb   (단일 파일 — 가장 깔끔)
  2순위 .gltf  (+ 같은 이름 .bin 과 텍스처 폴더가 함께 필요하다)
  3순위 .obj   (+ .mtl 과 텍스처)
같은 이름의 모델이 여러 형식으로 있으면 위 순서로 하나만 가져온다.
FBX 는 건너뛴다 — Godot 4 가 읽긴 하지만 변환기가 필요해 실패하기 쉽다.

설치하면 res://assets3d/models/<팩이름>/ 아래에 놓이고,
data/models.json 의 catalog 가 갱신된다. 경로를 그 목록에서 골라 쓰면 된다.
"""
import json
import pathlib
import shutil
import sys
import zipfile

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEST = ROOT / "assets3d" / "models"
MODELS_JSON = ROOT / "data" / "models.json"

MODEL_EXT = [".glb", ".gltf", ".obj"]          ## 우선순위 순서
SIDE_EXT = [".bin", ".mtl", ".png", ".jpg", ".jpeg", ".tga", ".webp"]
SKIP_DIR = ["__macosx", "source", "blend"]


def pack_name(zip_path: pathlib.Path) -> str:
    n = zip_path.stem
    for junk in ["kenney_", "Kenney_", " by @Quaternius", "[Standard]"]:
        n = n.replace(junk, "")
    # 구글 드라이브가 붙이는 -20260728T132300Z-1-001 같은 꼬리를 뗀다
    for sep in ["-2026", "-2025", "-2024"]:
        if sep in n:
            n = n.split(sep)[0]
    n = n.strip().strip("-_ ").replace(" ", "-").lower()
    parts = n.rsplit("_", 1)
    if len(parts) == 2 and parts[1].replace(".", "").isdigit():
        n = parts[0]
    return n or "pack"


def looks_like_asset(z: zipfile.ZipFile) -> bool:
    for e in z.namelist():
        if e.lower().endswith(tuple(MODEL_EXT)):
            return True
    return False


def install(zip_path: pathlib.Path) -> list:
    if not zip_path.exists():
        print("  없음:", zip_path)
        return []
    try:
        z = zipfile.ZipFile(zip_path)
    except Exception as exc:
        print("  열기 실패: %s (%s)" % (zip_path.name, exc))
        return []
    if not looks_like_asset(z):
        return []

    name = pack_name(zip_path)
    out = DEST / name
    out.mkdir(parents=True, exist_ok=True)

    # 같은 모델이 여러 형식이면 우선순위가 높은 것 하나만
    best = {}
    for entry in z.namelist():
        low = entry.lower()
        if any(("/%s/" % d) in ("/" + low) for d in SKIP_DIR):
            continue
        base = entry.rsplit("/", 1)[-1]
        stem, dot, ext = base.rpartition(".")
        ext = "." + ext.lower()
        if ext not in MODEL_EXT:
            continue
        rank = MODEL_EXT.index(ext)
        if stem not in best or rank < best[stem][0]:
            best[stem] = (rank, entry, ext)

    made = []
    wanted_sides = set()
    for stem, (_r, entry, ext) in best.items():
        target = out / (stem + ext)
        with z.open(entry) as src, open(target, "wb") as dst:
            shutil.copyfileobj(src, dst)
        made.append("res://assets3d/models/%s/%s%s" % (name, stem, ext))
        if ext in (".gltf", ".obj"):
            wanted_sides.add(entry.rsplit("/", 1)[0])   ## 같은 폴더의 부속 파일

    # .gltf/.obj 는 .bin·.mtl·텍스처가 함께 있어야 열린다
    sides = 0
    for entry in z.namelist():
        low = entry.lower()
        if not low.endswith(tuple(SIDE_EXT)):
            continue
        folder = entry.rsplit("/", 1)[0]
        if folder not in wanted_sides and not any(
                folder.startswith(w) or w.startswith(folder) for w in wanted_sides):
            continue
        base = entry.rsplit("/", 1)[-1]
        target = out / base
        if target.exists():
            continue
        with z.open(entry) as src, open(target, "wb") as dst:
            shutil.copyfileobj(src, dst)
        sides += 1

    print("  %-46s 모델 %3d · 부속 %3d → %s" % (zip_path.name, len(made), sides, out.name))
    return made


def rebuild_catalog() -> dict:
    cat = {}
    for f in sorted(DEST.rglob("*")):
        if f.suffix.lower() not in MODEL_EXT:
            continue
        rel = f.relative_to(DEST)
        pack = rel.parts[0] if len(rel.parts) > 1 else "base"
        cat.setdefault(pack, []).append("res://assets3d/models/" + "/".join(rel.parts))
    return cat


def install_folder(folder: pathlib.Path) -> list:
    """이미 압축을 푼 폴더에서 모델만 골라 복사한다.
    rar 처럼 여기서 못 여는 형식은 직접 푼 뒤 이 경로를 넘기면 된다."""
    if not folder.is_dir():
        return []
    best = {}
    for f in folder.rglob("*"):
        if not f.is_file():
            continue
        ext = f.suffix.lower()
        if ext not in MODEL_EXT:
            continue
        if any(d in str(f).lower() for d in SKIP_DIR):
            continue
        rank = MODEL_EXT.index(ext)
        if f.stem not in best or rank < best[f.stem][0]:
            best[f.stem] = (rank, f)

    name = pack_name(folder)
    out = DEST / name
    out.mkdir(parents=True, exist_ok=True)
    made = []
    for stem, (_r, f) in best.items():
        safe = stem.replace(" ", "_") + f.suffix.lower()
        shutil.copy2(f, out / safe)
        made.append("res://assets3d/models/%s/%s" % (name, safe))
        # gltf/obj 는 부속 파일이 함께 있어야 열린다
        if f.suffix.lower() in (".gltf", ".obj"):
            for side in f.parent.iterdir():
                if side.is_file() and side.suffix.lower() in SIDE_EXT:
                    t = out / side.name.replace(" ", "_")
                    if not t.exists():
                        shutil.copy2(side, t)
    print("  %-46s 모델 %3d → %s" % (folder.name[:46], len(made), out.name))
    return made


def main() -> None:
    args = [pathlib.Path(a) for a in sys.argv[1:]]
    if not args:
        args = sorted((pathlib.Path.home() / "Downloads").glob("*.zip"))

    DEST.mkdir(parents=True, exist_ok=True)
    print("== 3D 에셋 설치 ==")
    installed = 0
    for a in args:
        got = install_folder(a) if a.is_dir() else install(a)
        if got:
            installed += 1
    if installed == 0:
        print("  설치할 모델이 없었다.")

    cat = rebuild_catalog()
    d = json.loads(MODELS_JSON.read_text(encoding="utf-8")) if MODELS_JSON.exists() else {}
    d["catalog"] = cat
    d["catalog_note"] = ("설치된 모델 목록. 여기서 경로를 골라 player/enemies/props 에 붙인다. "
                         "tools/install_3d_assets.py 가 자동으로 채운다.")
    MODELS_JSON.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    total = sum(len(v) for v in cat.values())
    print("== catalog 갱신: 팩 %d개 · 모델 %d개 ==" % (len(cat), total))
    for k in sorted(cat):
        print("   %-28s %d" % (k, len(cat[k])))


if __name__ == "__main__":
    main()
