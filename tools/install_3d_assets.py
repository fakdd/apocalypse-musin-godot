"""로컬 zip 에서 3D 에셋을 꺼내 프로젝트에 설치한다.

    python tools/install_3d_assets.py            # ~/Downloads 의 zip 전부
    python tools/install_3d_assets.py a.zip b.zip

**인터넷에서 내려받지는 않는다.** 자동 다운로드는 이 환경에서 불가능해서,
받아 둔 zip 을 넣기만 하면 되게 만들었다. 아래 목록에서 직접 받아
~/Downloads 에 두고 이 스크립트를 돌리면 된다.

받을 곳 (전부 CC0 · 상업 이용 가능)
  건축/던전   https://kenney.nl/assets/modular-dungeon-kit     ← 이미 설치됨
  자연/폐허   https://kenney.nl/assets/nature-kit
  성/고딕     https://kenney.nl/assets/castle-kit
  무기        https://kenney.nl/assets/blaster-kit  (SF)
              https://quaternius.com/packs/ultimatestylizedweapons.html (판타지 무기)
  캐릭터      https://quaternius.com/packs/ultimatemonsters.html   (몬스터 40종)
              https://quaternius.com/packs/universalanimationlibrary.html (애니메이션)

설치하면 res://assets3d/models/<팩이름>/ 아래에 .glb 만 복사되고,
data/models.json 의 catalog 항목이 갱신된다. 경로를 그 목록에서 골라 쓰면 된다.
"""
import json
import os
import pathlib
import shutil
import sys
import zipfile

# 콘솔이 cp949 라 한글/기호 출력이 깨진다 — UTF-8 로 강제한다
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEST = ROOT / "assets3d" / "models"
MODELS_JSON = ROOT / "data" / "models.json"


def pack_name(zip_path: pathlib.Path) -> str:
    n = zip_path.stem.lower()
    for junk in ("kenney_", "quaternius_"):
        n = n.replace(junk, "")
    return n.rsplit("_", 1)[0] if n.rsplit("_", 1)[-1].replace(".", "").isdigit() else n


def install(zip_path: pathlib.Path) -> list:
    if not zip_path.exists():
        print("  없음:", zip_path)
        return []
    name = pack_name(zip_path)
    out = DEST / name
    out.mkdir(parents=True, exist_ok=True)
    made = []
    with zipfile.ZipFile(zip_path) as z:
        for entry in z.namelist():
            if not entry.lower().endswith(".glb"):
                continue
            base = entry.rsplit("/", 1)[-1]
            target = out / base
            with z.open(entry) as src, open(target, "wb") as dst:
                shutil.copyfileobj(src, dst)
            made.append("res://assets3d/models/%s/%s" % (name, base))
    print("  %-28s .glb %d개 → %s" % (zip_path.name, len(made), out))
    return made


def main() -> None:
    args = [pathlib.Path(a) for a in sys.argv[1:]]
    if not args:
        dl = pathlib.Path.home() / "Downloads"
        args = sorted(dl.glob("*.zip"))
    if not args:
        print("설치할 zip 이 없다. ~/Downloads 에 에셋 zip 을 두고 다시 실행할 것.")
        print(__doc__)
        return

    DEST.mkdir(parents=True, exist_ok=True)
    catalog = {}
    print("== 3D 에셋 설치 ==")
    for a in args:
        paths = install(a)
        if paths:
            catalog[pack_name(a)] = sorted(paths)

    if not catalog:
        return

    # models.json 의 catalog 만 갱신한다 (사용자가 적어 둔 매핑은 건드리지 않는다)
    d = json.loads(MODELS_JSON.read_text(encoding="utf-8")) if MODELS_JSON.exists() else {}
    old = d.get("catalog", {})
    old.update(catalog)
    d["catalog"] = old
    d["catalog_note"] = ("설치된 .glb 목록. 여기서 경로를 골라 player/enemies/props 에 붙인다. "
                         "tools/install_3d_assets.py 가 자동으로 채운다.")
    MODELS_JSON.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    total = sum(len(v) for v in old.values())
    print("== models.json catalog 갱신 — 팩 %d개 · 모델 %d개 ==" % (len(old), total))


if __name__ == "__main__":
    main()
