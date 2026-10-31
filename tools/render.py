# 简易软件光栅器：按 PortLayout.json 预览场景（与 SceneKit 相机参数一致，近似）
import json,struct,math,sys,numpy as np
from PIL import Image
MD="/workspace/FishingIdle/App/Resources/Models/"
_cache={}
def mesh(name):
    if name not in _cache:
        d=open(MD+name+".mesh","rb").read(); n=struct.unpack("<I",d[:4])[0]
        _cache[name]=np.frombuffer(d[4:],dtype="<f4").reshape(n,9).copy()
    return _cache[name]
def prim(kind,size,color):
    # 生成简单的盒/圆柱/球三角网格（扁平色）
    c=np.array(color[:3],dtype="f4")
    tris=[]
    if kind=="box":
        w,h,l=[s/2 for s in size]
        P=np.array([[x,y,z] for x in(-w,w) for y in(-h,h) for z in(-l,l)])
        faces=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
        for f in faces:
            for t in ((f[0],f[1],f[2]),(f[0],f[2],f[3])): tris.append(P[list(t)])
    elif kind=="cyl":
        r,h=size[0],size[1]; N=16
        for i in range(N):
            a0=2*math.pi*i/N; a1=2*math.pi*(i+1)/N
            p0=[r*math.cos(a0),-h/2,r*math.sin(a0)]; p1=[r*math.cos(a1),-h/2,r*math.sin(a1)]
            q0=[p0[0],h/2,p0[2]]; q1=[p1[0],h/2,p1[2]]
            tris+= [np.array([p0,q0,q1]),np.array([p0,q1,p1]),np.array([[0,h/2,0],q1,q0]),np.array([[0,-h/2,0],p0,p1])]
    elif kind=="sphere":
        r=size[0]; N=10
        for i in range(N):
            for j in range(N*2):
                def pt(a,b): return [r*math.sin(a)*math.cos(b),r*math.cos(a),r*math.sin(a)*math.sin(b)]
                a0=math.pi*i/N;a1=math.pi*(i+1)/N;b0=math.pi*j/N;b1=math.pi*(j+1)/N
                tris+=[np.array([pt(a0,b0),pt(a1,b0),pt(a1,b1)]),np.array([pt(a0,b0),pt(a1,b1),pt(a0,b1)])]
    out=[]
    for t in tris:
        n=np.cross(t[1]-t[0],t[2]-t[0]); n=n/(np.linalg.norm(n)+1e-9)
        if np.dot(n,t.mean(0))<0: n=-n
        for v in t: out.append([*v,*n,*c])
    return np.array(out,dtype="f4")
def xf(a,pos,ry,s,tint=None):
    a=a.copy(); c,sn=math.cos(ry),math.sin(ry)
    R=np.array([[c,0,sn],[0,1,0],[-sn,0,c]],dtype="f4")
    S=np.array(s if isinstance(s,list) else [s,s,s],dtype="f4")
    a[:,:3]=(a[:,:3]*S)@R.T+np.array(pos,dtype="f4")
    a[:,3:6]=a[:,3:6]@R.T
    if tint: a[:,6:9]*=np.array(tint,dtype="f4")
    return a
def node_tris(n,prefabs):
    pos=n.get("p",[0,0,0]); ry=math.radians(n.get("ry",0)); s=n.get("s",1); rx=math.radians(n.get("rx",0))
    if "m" in n: base=mesh(n["m"])
    elif "prefab" in n:
        base=np.concatenate([node_tris(c,prefabs) for c in prefabs[n["prefab"]]])
    else: base=prim(n["k"],n["size"],n["c"])
    if rx:
        base=base.copy(); c,sn=math.cos(rx),math.sin(rx); Rx=np.array([[1,0,0],[0,c,-sn],[0,sn,c]],"f4")
        base[:,:3]=base[:,:3]@Rx.T; base[:,3:6]=base[:,3:6]@Rx.T
    return xf(base,pos,ry,s,n.get("tint"))
def render(layout,extra,out,W=470,H=640):
    L=json.load(open(layout)); cam=L["camera"]
    T=[node_tris(n,L["prefabs"]) for n in L["nodes"]+extra]
    A=np.concatenate(T)
    eye=np.array(cam["pos"],"f4"); tgt=np.array(cam["look"],"f4")
    f=tgt-eye; f/=np.linalg.norm(f); r=np.cross(f,[0,1,0]); r/=np.linalg.norm(r); u=np.cross(r,f)
    P=A[:,:3]-eye; x=P@r; y=P@u; z=P@f
    fy=1/math.tan(math.radians(cam["fov"])/2)
    sx=(x/z*fy*(H/2))+W/2; sy=H/2-(y/z*fy*(H/2))
    L_dir=np.array(L.get("sunDir",[-0.4,-0.8,-0.45]),"f4"); L_dir/=np.linalg.norm(L_dir)
    nd=np.clip(-(A[:,3:6]@L_dir),0,1)
    col=A[:,6:9]*(0.55+0.6*nd[:,None])
    img=np.zeros((H,W,3),"f4"); img[:]=np.array([0.24,0.75,0.82])
    # 海面渐变
    import water
    gx,gy=np.meshgrid(np.arange(W)+0.5,np.arange(H)+0.5)
    dx=(gx-W/2)/(fy*H/2); dy=-(gy-H/2)/(fy*H/2)
    ray=f[None,None,:]+dx[...,None]*r+dy[...,None]*u
    tt=-eye[1]/ray[...,1]
    hx=eye[0]+tt*ray[...,0]; hz=eye[2]+tt*ray[...,2]
    img[:]=water.color(hx,hz)
    zb=np.full((H,W),1e9,"f4")
    n=len(A)//3
    for i in range(n):
        idx=slice(3*i,3*i+3)
        zs=z[idx]
        if (zs<=0.1).any(): continue
        xs=sx[idx]; ys=sy[idx]
        x0=max(int(xs.min()),0);x1=min(int(xs.max())+1,W);y0=max(int(ys.min()),0);y1=min(int(ys.max())+1,H)
        if x0>=x1 or y0>=y1: continue
        gx,gy=np.meshgrid(np.arange(x0,x1)+0.5,np.arange(y0,y1)+0.5)
        (ax,bx,cx),(ay,by,cy)=xs,ys
        d=(by-cy)*(ax-cx)+(cx-bx)*(ay-cy)
        if abs(d)<1e-9: continue
        w0=((by-cy)*(gx-cx)+(cx-bx)*(gy-cy))/d; w1=((cy-ay)*(gx-cx)+(ax-cx)*(gy-cy))/d; w2=1-w0-w1
        m=(w0>=0)&(w1>=0)&(w2>=0)
        if not m.any(): continue
        zz=w0*zs[0]+w1*zs[1]+w2*zs[2]
        sub=zb[y0:y1,x0:x1]; m&=zz<sub
        sub[m]=zz[m]
        c=col[3*i:3*i+3].mean(0)
        img[y0:y1,x0:x1][m]=c
    Image.fromarray((np.clip(img,0,1)*255).astype("u1")).save(out)
if __name__=="__main__":
    extra=json.loads(sys.argv[3]) if len(sys.argv)>3 else []
    render(sys.argv[1],extra,sys.argv[2])
