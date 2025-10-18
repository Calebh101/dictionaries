<p align="center" style="font-size:48px;">Dictionaries</p>
<p align="center">Dictionaries is a tool to view and edit data files like JSON, YAML, and more in a user-friendly and intuitive tree view.</p>

# Binary File Format

With this new app came a new file type: `application/xc-dict`, or `.dictionary`. This is where I'm gonna document all of it.

First, the naming. The MIME type is `application/xc-dict`, because I feel like `application/dictionary` could collide with a different program. The file extension is typically `.dictionary`, but `.xc-dict` is also accepted.

## File Content

Now the actual file content. Assume everything is big endian unless otherwise stated. Note that at the end of the file, 16 bytes are dedicated to a watermark; this is trimmed off immediately in parsing.

### Header

The header is the first thing, and it's padded to 128 bytes (if I ever need to store more data). The first 10 bytes or so is the magic: `XC-DICT` padded by 0s on the right. After this is an unsigned 16-bit integer dictating the header size (if it ever needs to be expanded), and after that is the binary file version. This is a sequence of 5 16-bit signed little endian integers, which are parsed as a `Version` object in the code.

### Data

After the header and padding is the actual content. The first 8 bytes of the file content tells us how many root children there are. This isn't really useful, but it's here to stay. After this, each root node goes like this:

- 8 bytes = unsigned integer stating length of entire node, including signature
- 1 byte = signature (see Signatures)
- Node content (see below)

Use the 8-byte length to determine how long the signature + node content is, then parse that individually, and move on to the next child.

#### Nodes

After the signature, there is an unsigned 64-bit integer saying how long the attribute data is, then the rest is just raw data.

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
