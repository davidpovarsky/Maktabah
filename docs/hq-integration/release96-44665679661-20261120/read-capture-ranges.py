"""Read the original Release96 capture ZIP directory/selected entries via HTTP206.

The full 3.11GB ZIP is never downloaded or claimed hash-verified. GitHub metadata,
the exact returned byte ranges and selected ZipFile CRC checks are retained.
Credentials/SAS URLs are kept only in process memory, never in evidence.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import urllib.error
import urllib.request
import zipfile


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


class RangeFile(io.RawIOBase):
    def __init__(self, url, size, out):
        self.url, self.size, self.out = url, size, out
        self.position, self.ranges, self.cache = 0, [], {}

    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.position

    def seek(self, offset, whence=0):
        self.position = (0 if whence == 0 else self.position if whence == 1 else self.size) + offset
        assert 0 <= self.position <= self.size
        return self.position

    def read(self, count=-1):
        count = self.size-self.position if count < 0 else min(count,self.size-self.position)
        assert 0 <= count <= 32*1024*1024, "refuse unbounded/full-archive fetch"
        if count == 0:return b""
        start,end=self.position,self.position+count-1
        key=(start,end)
        if key in self.cache:
            data=self.cache[key]
        else:
            request=urllib.request.Request(self.url,headers={"Range":f"bytes={start}-{end}"})
            with urllib.request.urlopen(request,timeout=60) as response:
                assert response.status==206
                assert response.headers["Content-Range"]==f"bytes {start}-{end}/{self.size}"
                data=response.read(count+1)
            assert len(data)==count
            digest=hashlib.sha256(data).hexdigest()
            name=f"range-{start}-{end}.bin"
            (self.out/"ranges"/name).write_bytes(data)
            self.ranges.append(dict(start=start,end=end,bytes=count,sha256=digest,file="ranges/"+name))
            self.cache[key]=data
        self.position+=count
        return data


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact-id",type=int,default=14608653727)
    parser.add_argument("--output",required=True,type=Path)
    parser.add_argument("--entry",action="append",default=[])
    parser.add_argument("--max-entry-bytes",type=int,default=8*1024*1024)
    args=parser.parse_args()
    out=args.output.resolve();assert not out.exists();out.mkdir(parents=True);(out/"ranges").mkdir()
    route=f"repos/davidpovarsky/Maktabah/actions/artifacts/{args.artifact_id}"
    metadata=json.loads(subprocess.check_output(["gh","api",route],text=True,encoding="utf-8",timeout=45))
    assert metadata["id"]==args.artifact_id and metadata["expired"] is False
    assert metadata["workflow_run"]["id"]==44665679661
    assert metadata["workflow_run"]["head_sha"]=="9cc346601bdb3fdda34c2c6ac59894f71dc9ea49"
    token=subprocess.check_output(["gh","auth","token"],text=True,encoding="utf-8",timeout=20).strip()
    request=urllib.request.Request("https://api.github.com/"+route+"/zip",headers={"Authorization":"Bearer "+token,"Accept":"application/vnd.github+json"})
    try:
        urllib.request.build_opener(NoRedirect).open(request,timeout=45)
    except urllib.error.HTTPError as error:
        assert error.code in (301,302,303,307,308)
        url=error.headers["Location"]
    else:
        raise AssertionError("Expected authenticated artifact redirect")
    assert url.startswith("https://")
    token=None;request=None
    remote=RangeFile(url,metadata["size_in_bytes"],out)
    selected=[]
    with zipfile.ZipFile(remote) as archive:
        entries=[dict(path=i.filename,bytes=i.file_size,compressedBytes=i.compress_size,
                      headerOffset=i.header_offset,crc32=f"{i.CRC:08x}",compression=i.compress_type)
                 for i in archive.infolist()]
        for name in args.entry:
            info=archive.getinfo(name)
            assert info.file_size<=args.max_entry_bytes and info.compress_size<=32*1024*1024
            relative=PurePosixPath(name);assert not relative.is_absolute() and ".." not in relative.parts
            data=archive.read(name)
            destination=out/"entries"/Path(*relative.parts);destination.parent.mkdir(parents=True,exist_ok=True)
            destination.write_bytes(data)
            selected.append(dict(zipEntry=name,bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),
                                 crc32=f"{info.CRC:08x}",crcValidatedByZipFile=True))
    (out/"CENTRAL_DIRECTORY_INDEX.json").write_text(json.dumps(entries,indent=2)+"\n")
    (out/"ARTIFACT_METADATA.json").write_text(json.dumps(metadata,indent=2)+"\n")
    proof=dict(artifactID=args.artifact_id,archiveBytes=metadata["size_in_bytes"],
               advertisedDigest=metadata["digest"],fullArchiveHashVerified=False,
               method="Authenticated redirect and exact HTTP206 ranges; selected CRC validation",
               ranges=remote.ranges,transferredBytes=sum(x["bytes"] for x in remote.ranges),selected=selected)
    (out/"RANGE_EVIDENCE.json").write_text(json.dumps(proof,indent=2)+"\n")
    print(json.dumps({"output":str(out),"entries":len(entries),"transferredBytes":proof["transferredBytes"],
                      "selected":selected},ensure_ascii=False))


if __name__=="__main__":main()
