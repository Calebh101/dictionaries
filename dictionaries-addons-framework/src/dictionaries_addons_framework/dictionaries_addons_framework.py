"""Main module."""

from abc import ABC, abstractmethod
from enum import Enum
import json
import random
import string
from typing import List

class DictionariesAddonFunctionInputType(Enum):
    PLIST_UTF8 = 1
    JSON_UTF8 = 2
    YAML_UTF8 = 3
    DICTIONARY_RAW = 4

class DictionariesAddonFunctionOutputType(Enum):
    PLIST_UTF8 = 1
    JSON_UTF8 = 2
    YAML_UTF8 = 3
    DICTIONARY_RAW = 4

class DictionariesDialogueModuleType(Enum):
    TEXT = 1
    BUTTON = 2
    STRING_INPUT = 3

def _internalCall(type: str, data: dict):
    print(f"_DICTIONARIES_INTERNAL_API_CALL: {json.dumps({"type": type, "data": data})}")

class DictionariesAddon:
    """Base class addon authors inherit from."""

    def __init__(self, name: str, version: str, author: str | List[str] | None) -> None:
        self.name = name
        self.version = version

        if isinstance(author, str):
            self.author = [author]
        else:
            self.author = author or []

class DictionariesAddonFunction:
    """Class for making Python functions that can take inputs and output something."""

    def __init__(self, name: str, description: str, inputs: List[DictionariesAddonFunctionInputType], outputs: List[DictionariesAddonFunctionOutputType]) -> None:
        self.name = name
        self.description = description
        self.inputs = inputs
        self.outputs = outputs

class _DictionariesDialogueModule(ABC):
    def __init__(self, type: DictionariesDialogueModuleType) -> None:
        self.type = type
        self.id = ''.join(random.choice(string.ascii_letters) for _ in range(8))

    @abstractmethod
    def getResult(self):
        """Subclasses must implement this method"""
        raise NotImplementedError()

    def onInput(self, data: dict) -> None:
        """Subclasses may implement this method"""
        pass

    @abstractmethod
    def toJson(self) -> dict:
        """Subclasses must implement this method"""
        raise NotImplementedError()

class DictionariesDialogueTextModule(_DictionariesDialogueModule):
    def __init__(self, text: str) -> None:
        super().__init__(DictionariesDialogueModuleType.TEXT)
        self.text = text

    def getResult(self, data):
        return None

    def toJson(self):
        return {
            "text": self.text
        }

class DictionariesDialogueButtonModule(_DictionariesDialogueModule):
    exitOnPressed = True

    def __init__(self, text: str, exitOnPressed: bool):
        super().__init__(DictionariesDialogueModuleType.BUTTON)
        self.text = text
        self.pressed = False
        self.exitOnPressed = exitOnPressed

    def onInput(self, data):
        self.pressed = True

    def getResult(self):
        return self.pressed

    def toJson(self):
        return {
            "text": self.text
        }

class DictionariesDialogueTextInputModule(_DictionariesDialogueModule):
    isFileSelect = False
    isFolderSelect = False

    def __init__(self, hint: str, isFileSelect: bool, isFolderSelect: bool):
        super().__init__(DictionariesDialogueModuleType.STRING_INPUT)

        self.hint = hint
        self.text = ""

        self.isFileSelect = isFileSelect
        self.isFolderSelect = isFolderSelect

    def onInput(self, data):
        self.text = data["text"]

    def getResult(self):
        return self.text

    def toJson(self):
        return {
            "hint": self.hint,
            "isFileSelect": self.isFileSelect,
            "isFolderSelect": self.isFolderSelect
        }

class DictionariesDialogue:
    def __init__(self, modules: List[_DictionariesDialogueModule]) -> None:
        self.modules = modules

    def toJson(self) -> dict:
        return {
            "modules": [{"id": module.id, "type": module.type.value, "data": module.toJson()} for module in self.modules]
        }

class DictionariesApplication:
    @staticmethod
    def callDialogue(dialogue: DictionariesDialogue):
        _internalCall("dialogue.new", {"dialogue": dialogue.toJson()})