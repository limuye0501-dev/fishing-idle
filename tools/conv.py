import struct,os,sys
from PIL import Image
OUT="/workspace/FishingIdle/App/Resources/Models"
def conv(kit,name,outname):
    d=f"{kit}/Models/OBJ format/"
    mats={}; cur=None; tex={}
    for line in open(d+name+".mtl"):
        p=line.split()
        if not p: continue
        if p[0]=="newmtl": cur=p[1]; mats[cur]={"Kd":(1,1,1),"tex":None}
        elif p[0]=="Kd": mats[cur]["Kd"]=tuple(map(float,p[1:4]))
        elif p[0]=="map_Kd":
            path=d+" ".join(p[1:])
            if path not in tex: tex[path]=Image.open(path).convert("RGB")
            mats[cur]["tex"]=path
    V=[];N=[];T=[];tris=[];m=None
    for line in open(d+name+".obj"):
        p=line.split()
        if not p: continue
        if p[0]=="v": V.append(tuple(map(float,p[1:4])))
        elif p[0]=="vn": N.append(tuple(map(float,p[1:4])))
        elif p[0]=="vt": T.append(tuple(map(float,p[1:3])))
        elif p[0]=="usemtl": m=p[1]
        elif p[0]=="f":
            idx=[]
            for c in p[1:]:
                a=c.split("/"); vi=int(a[0])-1; ti=int(a[1])-1 if len(a)>1 and a[1] else None; ni=int(a[2])-1 if len(a)>2 and a[2] else None
                idx.append((vi,ti,ni))
            for k in range(1,len(idx)-1): tris.append((m,idx[0],idx[k],idx[k+1]))
    buf=bytearray()
    for m,*vs in tris:
        mt=mats.get(m,{"Kd":(1,1,1),"tex":None})
        # flat color per triangle: sample centroid uv
        if mt["tex"] and vs[0][1] is not None:
            im=tex[mt["tex"]]; u=sum(T[v[1]][0] for v in vs)/3; w=sum(T[v[1]][1] for v in vs)/3
            x=min(im.width-1,max(0,int((u%1.0001)*im.width))); y=min(im.height-1,max(0,int((1-(w%1.0001))*im.height)))
            col=tuple(c/255 for c in im.getpixel((x,y)))
            col=tuple(col[i]*mt["Kd"][i] for i in range(3))
        else: col=mt["Kd"]
        a,b,c=[V[v[0]] for v in vs]
        ux,uy,uz=[b[i]-a[i] for i in range(3)]; vx,vy,vz=[c[i]-a[i] for i in range(3)]
        n=(uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx); l=(sum(x*x for x in n))**.5 or 1; fn=tuple(x/l for x in n)
        for v in vs:
            nn=N[v[2]] if v[2] is not None else fn
            buf+=struct.pack("<9f",*V[v[0]],*nn,*col)
    open(f"{OUT}/{outname}.mesh","wb").write(struct.pack("<I",len(tris)*3)+buf)
    return len(tris)
L=[("watercraft-kit","boat-fishing-small"),("watercraft-kit","boat-row-large"),("watercraft-kit","buoy"),("watercraft-kit","buoy-flag"),
("pirate-kit","structure-platform-dock"),("pirate-kit","structure-platform-dock-small"),("pirate-kit","platform-planks"),("pirate-kit","structure-platform"),("pirate-kit","structure-roof"),("pirate-kit","structure"),("pirate-kit","rocks-a"),("pirate-kit","rocks-b"),("pirate-kit","rocks-c"),("pirate-kit","rocks-sand-a"),("pirate-kit","barrel"),("pirate-kit","crate"),("pirate-kit","crate-bottles"),("pirate-kit","palm-bend"),("pirate-kit","structure-fence"),("pirate-kit","patch-grass-foliage"),
("survival-kit","box-large"),("survival-kit","barrel"),("survival-kit","fish"),("survival-kit","signpost-single"),("survival-kit","bucket"),("survival-kit","rock-flat-grass"),("survival-kit","resource-planks"),
("nature-kit","path_stone"),("nature-kit","path_stoneCircle"),("nature-kit","plant_bush"),("nature-kit","plant_bushLarge"),("nature-kit","flower_yellowA"),("nature-kit","flower_redA"),("nature-kit","grass_large"),("nature-kit","tree_default"),("nature-kit","stone_largeA"),("nature-kit","stone_tallA"),("nature-kit","plant_flatShort")]
for kit,n in L:
    out=f"{kit.split('-')[0]}_{n}".replace("-","_")
    try: print(out,conv(kit,n,out))
    except Exception as e: print("FAIL",kit,n,e)
