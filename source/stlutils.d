/** Some utility for reading and writing both ASCII and binary STL files

based on https://en.wikipedia.org/wiki/STL_(file_format)

Copyright:
 Copyright (c) 2021, Ferhat Kurtulmuş.

 License:
   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
*/
module stlutils;

import std.stdio;
import std.exception;
import std.string;
import std.uni : isWhite;
import std.array : split;
import std.range;
import std.conv;

// TODO: use exceptions more for error handling

final class STL {
    public float[] normals;
    public float[] vertices;

    // this makes only sense  for binary stl format
    public ubyte[80] header = cast(ubyte[80])"##Binary STL####################################################################";
    
    // in the standard format, attributes should be zero because most software does not understand anything else
    // public ushort[] attributes; // maybe implement this.

    package string fname;

    this(){
        
    }

    @property
    int numOfTriangles(){
        if(!vertices.length)
            return 0;
        return cast(int)vertices.length/9;
    }

    bool empty(){
        return vertices is null || !vertices.length;
    }
}

STL readSTL(string filePath){
    import std.path: baseName;
    
    auto stl = new STL();

    stl.fname = baseName(filePath, ".stl");

    if(!isBinarySTL(filePath))
        stl.readAsciiFile(filePath);
    else
        stl.readBinaryFile(filePath);

    return stl;
}

bool isBinarySTL(S)(auto ref S filePath){

    auto file = File(filePath, "r");
    scope(exit) file.close();

    char[] _line;
    file.readln(_line);
    
    enforce(_line.length, "File is not valid!");

    if(_line[0..5] == "solid")
        return false;
    
    return true;
}

void readAsciiFile(S)(STL stl, auto ref S filePath){
    auto file = File(filePath, "r");
    scope(exit) file.close();

    float parseFloat(S)(auto ref S str){
        return str.to!float;
    }

    // maybe preallocate vertices and normals based on the number of the lines
    stl.normals.reserve(20);
    stl.vertices.reserve(20*9);

    while (!file.eof){
        char[] _line;
        file.readln(_line);
        _line = chomp(_line);
        if(!_line.length) continue;

        string line = assumeUnique(_line);

        string[] tokens = line.strip.split!isWhite;

        if(tokens[0] == "vertex"){
            stl.vertices ~= parseFloat(tokens[1]);
            stl.vertices ~= parseFloat(tokens[2]);
            stl.vertices ~= parseFloat(tokens[3]);
        } else if(tokens[0] == "facet"){
            stl.normals ~= parseFloat(tokens[2]);
            stl.normals ~= parseFloat(tokens[3]);
            stl.normals ~= parseFloat(tokens[4]);
        }
            
    }
}

/* // write-at-once
void toBinarySTLFile(STL stl, string filePath){
    File fwriter;

    fwriter.open(filePath, "wb");
    scope(exit) fwriter.close();

    int numOfTri = stl.numOfTriangles;

    ubyte[] sysBuf = new ubyte[80+4+(12+12+12+12+2) * numOfTri];

    sysBuf[0..80] = stl.header[];
    
    sysBuf[80..84] = (cast(ubyte*)&numOfTri)[0..int.sizeof];
    
    short _attr = 0;

    int i;
    foreach (vchunk, nchunk; zip(chunks(stl.vertices, 9), chunks(stl.normals, 3))){

        ubyte[50] tbuff;

        tbuff[0..12] = cast(ubyte[])(nchunk[]);
        tbuff[12..48] = cast(ubyte[])(vchunk[]);
        
        tbuff[48..50] = (cast(ubyte*)&_attr)[0..short.sizeof];
        
        sysBuf[84 + i*50 .. 84 + (i+1)*50] = tbuff[];
        ++i;
    }
    
    fwriter.rawWrite(sysBuf[]);
}
*/

void toBinarySTLFile(STL stl, string filePath){
    File fwriter;

    fwriter.open(filePath, "wb");
    scope(exit) fwriter.close();

    int numOfTri = stl.numOfTriangles;

    fwriter.rawWrite(stl.header[]);
    
    fwriter.rawWrite((cast(ubyte*)&numOfTri)[0..int.sizeof]);
    
    short _attr = 0;
    
    foreach (vchunk, nchunk; zip(chunks(stl.vertices, 9), chunks(stl.normals, 3))){

        ubyte[50] tbuff;

        tbuff[0..12] = cast(ubyte[])(nchunk[]);
        tbuff[12..48] = cast(ubyte[])(vchunk[]);
        
        tbuff[48..50] = (cast(ubyte*)&_attr)[0..short.sizeof];

        fwriter.rawWrite(tbuff[]);
    }
}

void readBinaryFile(S)(STL stl, auto ref S filePath){
    File file;
    file.open(filePath, "rb");
    scope(exit) file.close();

    ubyte[80] _header;
    file.rawRead(_header[]);
    stl.header[] = _header[];

    ubyte[4] _numOfTriangles;
    file.rawRead(_numOfTriangles[]);

    int numOfTriangles = *(cast(int*)_numOfTriangles[].ptr);

    stl.normals = new float[numOfTriangles * 3];
    stl.vertices = new float[numOfTriangles * 9];

    //debug writeln(cast(string)assumeUnique( stl.header));
    //debug writeln(numOfTriangles);
    
    foreach (i; 0..numOfTriangles){

        ubyte[50] tbuff;

        file.rawRead(tbuff[]);

        stl.normals[i*3..(i+1)*3] = cast(float[])tbuff[0..12];
        stl.vertices[i*9..(i+1)*9] = cast(float[])tbuff[12..48];
        
        const short dummy_attr = *(cast(short*)tbuff[48..50].ptr);
    }
    
}

void toAsciiSTLFile(STL stl, string filePath){
    File file;
    file.open(filePath, "w");
    scope(exit) file.close();

    file.writeln("solid STLExport");

    foreach (vchunk, nchunk; zip(chunks(stl.vertices, 9), chunks(stl.normals, 3))){
        file.writefln("facet normal %f %f %f", nchunk[0], nchunk[1], nchunk[2]);
        file.writeln("   outer loop");
        file.writefln("      vertex %f %f %f", vchunk[0], vchunk[1], vchunk[2]);
        file.writefln("      vertex %f %f %f", vchunk[3], vchunk[4], vchunk[5]);
        file.writefln("      vertex %f %f %f", vchunk[6], vchunk[7], vchunk[8]);
        file.writeln("   endloop");
        file.writeln("endfacet");
    }

    file.writeln("endsolid STLExport");

}

void toOBJFile(STL stl, string filePath){
    File file;
    file.open(filePath, "w");
    scope(exit) file.close();

    file.writeln("#");
    file.writeln("# object STLExport");
    file.writeln("#");
    file.write("\n");

    foreach (v; chunks(stl.vertices, 9)){
        file.writefln("v %f %f %f", v[0], v[1], v[2]);
        file.writefln("v %f %f %f", v[3], v[4], v[5]);
        file.writefln("v %f %f %f", v[6], v[7], v[8]);
    }

    file.writefln("# %u vertices", stl.vertices.length/9);

    file.write("\n");

    foreach (n; chunks(stl.normals, 3)){
        file.writefln("vn %f %f %f", n[0], n[1], n[2]);
    }

    file.writefln("# %u vertex normals", stl.normals.length/3);

    file.write("\n");
    
    file.writeln("g STLExport");
    file.writeln("s 1");

    ulong a1 = 1, a2 = 1, b1 = 2, b2 = 1, c1 = 3, c2 = 1;

    foreach ( _ ; 0..stl.vertices.length/9){
        file.writefln("f %u//%u %u//%u %u//%u", a1, a2, b1, b2, c1, c2);
        a1 += 3;
        a2 += 1;
        b1 += 3;
        b2 += 1;
        c1 += 3;
        c2 += 1;
    }

    file.writefln("# %u polygons", stl.vertices.length/9);
}