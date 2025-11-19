<h1 align="center">Dictionaries</h1>
<p align="center">Dictionaries is a tool to view and edit data files like JSON, YAML, and more in a user-friendly and intuitive tree view.</p>

<p align="center">
  <a href="https://github.com/Calebh101/dictionaries/actions/workflows/pages.yml">
    <img src="https://github.com/Calebh101/dictionaries/actions/workflows/pages.yml/badge.svg">
  </a>
</p>

Hello, and welcome to Dictionaries! This is a cross-platform tool to view your "dictionaries", which are files like YAML, JSON, PList, my custom file type, `.dictionary`, and potentially more to come.

When you first open it up, you will get one of two screens:
- If you're on a small device, or the window is too small, you won't be able to use Dictionaries. However, I included a function to turn a file into a `.dictionary`.
- Otherwise, you'll see multiple options of how to open a new file; either by uploading your own, downloading one from the Internet, or by creating a new dictionary.

After this, you'll get an editor window. At the top you'll have some tabs; to start, you'll have the actual editor (represented by a pen icon) and a project window (represented by a gear icon). To unlock more tabs, get Dictionaries Plus. Nah, just click the Plus icon in the right of the tab bar to add a preview of a text file type like JSON, PList, etcetera.

# Binary File Format

With this new app came a new file type: `application/c-dict`, or `.dictionary`. This is where I'm gonna document all of it, for people who'd like to parse it in their own projects.

First, the naming. The MIME type is `application/c-dict`, because I feel like `application/dictionary` could collide with a different program. The file extension is typically `.dictionary`, but `.c-dict` is also accepted.

## File Content

Now the actual file content. Assume everything is big endian unless otherwise stated. Note that at the end of the file, 16 bytes are dedicated to a watermark; this is trimmed off immediately in parsing.

### Header

The header is the first thing, and it's padded to 128 bytes (if I ever need to store more data). The first 10 bytes or so is the magic: `C-DICT` padded by 0s on the right. After this is an unsigned 16-bit integer dictating the header size (if it ever needs to be expanded), and after that is the binary file vehow many root children there are. This isn't really useful, but it's here to stay.rsion. This is a sequence of 5 16-bit signed little endian integers, which are parsed as a `Version` object in the code.

### Data

After the header and padding is the actual content. The first 8 bytes of the file content tells us the size of the content. After this, each root node goes like this:

- X bytes = dynamic number representing length (see below)
- 1 byte = signature (see Signatures)
- Node content (see below)

Use the 8-byte length to determine how long the signature + node content is, then parse that individually, and move on to the next child.

#### Nodes

After the signature, the rest is just raw data.

##### Data

Arrays and dictionaries are different than typical data types, in that their bytes are the same layout as the root children layout from above (except that there's no 8 bytes determining child count).

Here's how the rest are parsed:

- String: UTF8
- Number: The first byte represents the type, and the next 8 represent the number.
    - The first byte is 0 if the number is a unsigned 64-bit integer, 1 if it's a 64-bit floating-point number.
- Boolean: 1 if true, 0 if false
- Empty: Literally nothing
- Date: Stored as 64-bit unsigned integer representing milliseconds since epoch
- Data: Read as raw bytes

#### Node Key Value Pairs

This is simple. It's a null-terminated string representing the key, then the data of a typical Node after that.

## Signatures

The signature is a singular byte that tells you exactly what that node is, and how to parse it.

First, the node varient. This is represented by the first 3 bits of the signature, as an unsigned 3-bit integer. `0` is a standard node, `1` is a node key value pair (for dictionaries). Anything other than that does not exist. The next 5 bytes is the node type (like string, array, etcetera). This is 0 and should be ignored if the node is a node key value pair.

Run `dart run bin/signatures.dart` to know all the different signatures.

## Dynamic Numbers

Dynamic numbers are numbers that use a dynamic amount of bytes. They consist of one byte as a signature for the number, and a dynamic amount of bytes afterwards for the content, based on the signature. See the [`DynamicNumber` Documentation](https://github.com/Calebh101/localpkg-dart#dynamic-numbers) for how to parse them.

# Addons

Addons are Python scripts that can provide extra utilities to Dictionaries. You can use them by going to Addons > Manage Addons in the menu bar.

## How do I make addons?

Use the package [dictionaries-addons-framework](https://pypi.org/project/dictionaries-addons-framework) to make your addons, then add an addon manually in Dictionaries that points to your main addon source file.