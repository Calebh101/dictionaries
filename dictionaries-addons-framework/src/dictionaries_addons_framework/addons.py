"""Main module."""

from abc import ABC, abstractmethod
import asyncio
from enum import Enum
import json
import queue
import random
import string
import sys
import threading
from typing import List, Sequence

registeredAddons: List[DictionariesAddon] = []

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

class Logger:
    @staticmethod
    def print(input: object):
        print(input)

    @staticmethod
    def verbose(input: object):
        print("VBS: " + str(input))

def _internalCall(type: str, data: dict):
    print(f"_DICTIONARIES_INTERNAL_API_CALL: {json.dumps({"type": type, "data": data})}")

class DictionariesAddon(ABC):
    """Base class addon authors inherit from.\n\nYou *must* call `register()` on this object."""
    registeredFunctions: List[DictionariesAddonFunction] = []

    def __init__(self, name: str, description: str, version: str, author: str | List[str] | None = None, website: str | None = None) -> None:
        self.name = name
        self.version = version
        self.description = description
        self.website = website

        if isinstance(author, str):
            self.author = [author]
        else:
            self.author = author or []

    @abstractmethod
    def onInitialize(self) -> None:
        """When Dictionaries is intialized, this function is ran."""
        pass

    def toJson(self) -> dict:
        return {
            "name": self.name,
            "version": self.version,
            "description": self.description,
            "website": self.website,
            "authors": self.author
        }

    def register(self) -> None:
        _internalCall(type="addon.register", data=self.toJson())
        registeredAddons.append(self)

class DictionariesAddonFunction(ABC):
    """Class for making Python functions that can take inputs and output something.\n\nYour addon needs to register this with `register()`."""

    def __init__(self, parent: DictionariesAddon, name: str, description: str, inputs: List[DictionariesAddonFunctionInputType], outputs: List[DictionariesAddonFunctionOutputType]) -> None:
        self.name = name
        self.description = description
        self.inputs = inputs
        self.outputs = outputs
        self.id = ''.join(random.choice(string.ascii_letters) for _ in range(8))
        self.parent = parent

    @abstractmethod
    def run(self, inputs: List[object]) -> object | None:
        """Return the object type you inputted when the script is run.\n\nThis function must be overriden."""
        raise NotImplementedError()

    def toJson(self) -> object:
        return {
            "name": self.name,
            "description": self.description,
            "inputs": [x.value for x in self.inputs],
            "outputs": [x.value for x in self.outputs],
            "id": self.id,
        }

    def register(self) -> None:
        _internalCall("function.register", {"function": self.toJson()})
        self.parent.registeredFunctions.append(self)

class DictionariesDialogueModule(ABC):
    def __init__(self, parent: DictionariesAddon, type: DictionariesDialogueModuleType) -> None:
        self.type = type
        self.id = ''.join(random.choice(string.ascii_letters) for _ in range(8))
        self.parent = parent

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

class DictionariesDialogueTextModule(DictionariesDialogueModule):
    def __init__(self, parent: DictionariesAddon, text: str) -> None:
        super().__init__(parent, DictionariesDialogueModuleType.TEXT)
        self.text = text

    def getResult(self, data):
        return None

    def toJson(self):
        return {
            "text": self.text
        }

class DictionariesDialogueButtonModule(DictionariesDialogueModule):
    def __init__(self, parent: DictionariesAddon, text: str, exitOnPressed: bool = True):
        super().__init__(parent, DictionariesDialogueModuleType.BUTTON)

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

class DictionariesDialogueTextInputModule(DictionariesDialogueModule):
    def __init__(self, parent: DictionariesAddon, hint: str, isFileSelect: bool = False, isFolderSelect: bool = False):
        super().__init__(parent, DictionariesDialogueModuleType.STRING_INPUT)

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
    def __init__(self, modules: Sequence[DictionariesDialogueModule]) -> None:
        self.modules = modules

    def toJson(self) -> dict:
        return {
            "modules": [{"id": module.id, "type": module.type.value, "data": module.toJson()} for module in self.modules]
        }

class DictionariesApplication:
    @staticmethod
    def callDialogue(dialogue: DictionariesDialogue) -> dict | None:
        """Note that this function is IO-blocking, and will stop the entire script until the dialogue returns."""
        _internalCall("dialogue.new", {"dialogue": dialogue.toJson()})
        line = sys.stdin.readline()

        try:
            if line:
                line = line.rstrip("\n")
                data = json.loads(line)
                if (not isinstance(data, dict)): return None;
                return data
        except:
            pass

        return None

async def listen():
    loop = asyncio.get_running_loop()
    reader = asyncio.StreamReader()
    protocol = asyncio.StreamReaderProtocol(reader)
    await loop.connect_read_pipe(lambda: protocol, sys.stdin)

    while True:
        line = await reader.readline()
        if not line: break
        print("got:", line.decode().rstrip("\n"))

asyncio.run(listen())