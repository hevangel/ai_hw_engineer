"""Read original DOS-created FAT16 independently of the hardware controller."""
def partition(image):
    assert len(image)==21307392 and image[510:512]==b'\x55\xaa','invalid MBR'
    active=[image[offset:offset+16] for offset in range(446,510,16) if image[offset]==0x80]
    assert len(active)==1 and active[0][4] in (4,6),'one active FAT16 DOS partition required'
    start=int.from_bytes(active[0][8:12],'little')
    sectors=int.from_bytes(active[0][12:16],'little')
    assert start>0 and sectors>0 and start+sectors<=41616,'partition geometry'
    return image[start*512:(start+sectors)*512]

def files(image):
    volume=partition(image)
    word=lambda offset:int.from_bytes(volume[offset:offset+2],'little')
    size,cluster_sectors,reserved,fats=word(11),volume[13],word(14),volume[16]
    roots,fat_sectors=word(17),word(22)
    assert size==512 and cluster_sectors in (1,2,4,8,16,32,64) and fats==2
    assert volume[510:512]==b'\x55\xaa' and fat_sectors>0
    root=(reserved+fats*fat_sectors)*size
    data=root+((roots*32+511)//512)*512
    clusters=(len(volume)-data)//(size*cluster_sectors)
    assert 4085<=clusters<65525,'expected FAT16'
    fat=volume[reserved*size:(reserved+fat_sectors)*size]
    assert fat==volume[(reserved+fat_sectors)*size:(reserved+2*fat_sectors)*size],'FAT copies disagree'
    result={}
    for position in range(root,root+roots*32,32):
        entry=volume[position:position+32]
        if entry[0]==0:break
        if entry[0]==0xe5 or entry[11]&0x18:continue
        cluster=int.from_bytes(entry[26:28],'little');length=int.from_bytes(entry[28:32],'little')
        payload=bytearray();visited=set()
        while len(payload)<length:
            assert 2<=cluster<clusters+2 and cluster not in visited,'invalid FAT16 chain'
            visited.add(cluster)
            offset=data+(cluster-2)*cluster_sectors*size
            payload.extend(volume[offset:offset+cluster_sectors*size])
            cluster=int.from_bytes(fat[cluster*2:cluster*2+2],'little')
        if length:assert cluster>=0xfff8,'file chain exceeds its declared size'
        result[entry[:11]]=bytes(payload[:length])
    return result
