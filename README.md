# stlutils
Some utility for reading and writing both ASCII and binary STL files {1}

1: The STL format is a CAD format used widely in 3D printing and rapid prototyping for the representation or approximation of surfaces by means of tesssellation

## How things work:
```d
import stlutils;

import std;

void main() {
    // read an ascii STL
    auto stl1 = readSTL("testdata/icosahedron.stl");

    writeln(stl1.vertices);
    writeln(stl1.normals);

    stl.toBinarySTLFile("icosahedron_bin.stl"); // write it as binary STL

    // read a binary STL
    auto stl2 = readSTL("testdata/femur.stl");

    writeln(stl2.vertices);
    writeln(stl2.normals);

    stl2.toAsciiSTLFile("femur_ascii.stl");

    // write to Wavefront .obj file
    stl2.toOBJFile("femur.obj");
}

```