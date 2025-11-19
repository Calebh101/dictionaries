from typing import List
from dictionaries_addons_framework import addons
import tempfile
from OCSnapshot import OCSnapshot
from pathlib import Path

class OCSnapshotAddon(addons.DictionariesAddon):
    def __init__(self) -> None:
        super().__init__(name="OC Snapshot", description="A utility that allows using CorpNewt's ProperTree's OC Snapshot feature for OpenCore config.plists.", version="1.0.0A", author=["CorpNewt", "Calebh101"])

    def onInitialize(self) -> None:
        raise NotImplementedError

addon = OCSnapshotAddon()

def askForOCFolder() -> Path | None:
    dialogue = addons.DictionariesDialogue(modules=[
        addons.DictionariesDialogueTextModule(text="Please select your OC folder of your EFI."),
        addons.DictionariesDialogueTextInputModule(hint="EFI/OC", isFolderSelect=True, isFileSelect=False)
    ])

    result = addons.DictionariesApplication.callDialogue(dialogue=dialogue)
    if (not isinstance(result, dict)): return None;
    path = Path(result["outputs"][0])
    if (path.exists()): return path;
    return None;

class OCSnapshotFunction(addons.DictionariesAddonFunction):
    def __init__(self) -> None:
        super().__init__(name="OC Snapshot", description="Perform an OC Snapshot on a config.plist. From CorpNewt's ProperTree.", inputs=[addons.DictionariesAddonFunctionInputType.PLIST_UTF8], outputs=[addons.DictionariesAddonFunctionOutputType.PLIST_UTF8])

    def run(self, inputs: List[object]) -> object | None:
        directory = Path(tempfile.gettempdir())
        path = directory / "config.plist"
        oc = askForOCFolder()

        if not oc or not oc.exists():
            dialogue = addons.DictionariesDialogue(modules=[
                addons.DictionariesDialogueTextModule(text="Unable to OC snapshot: OC folder doesn't exist.")
            ])

            addons.DictionariesApplication.callDialogue(dialogue=dialogue)
            return

        with open(str(path), "w") as file:
            file.write(str(inputs[0]))
            addons.Logger.print("Wrote plist file...")
            file.close()

            snapshotter = OCSnapshot.OCSnapshot()
            snapshotter.snapshot(str(path), str(path), oc, False)

            with open(str(path), "r", encoding="utf-8") as file:
                data = file.read()
                addons.Logger.print("Read new plist file...")
                return data