import importlib.util
from pathlib import Path
import sys

parent_dir = Path(__file__).resolve().parent
src = Path(parent_dir / ".." / ".." / "dictionaries-addons-framework" / "src").resolve()
sys.path.insert(0, str(src))

path = (src / "dictionaries_addons_framework" / "__init__.py").resolve()
spec = importlib.util.spec_from_file_location("dictionaries_addons_framework", path)

if spec is None: raise ImportError("Could not load spec")
if spec.loader is None: raise ImportError("Could not load loader")

module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

for name in dir(module):
    print(str(path) + ": " + name)

sys.modules["dictionaries_addons_framework"] = module