import numpy as np
def lin(h): c=np.array([int(h[i:i+2],16)/255 for i in (0,2,4)]); return c
ROCKS=[(-9,-12,2.6),(-10,-3,2.2),(7,-8,2.8),(8.5,-19,2.0)]
def sdbox(x,z,x0,x1,z0,z1):
    dx=np.maximum(np.maximum(x0-x,x-x1),0); dz=np.maximum(np.maximum(z0-z,z-z1),0); return np.sqrt(dx*dx+dz*dz)
def dist(x,z):
    d=sdbox(x,z,-10.5,11.3,4.8,13.0)
    d=np.minimum(d,sdbox(x,z,7.7,10.3,-0.3,4.8))
    for rx,rz,r in ROCKS: d=np.minimum(d,np.maximum(np.hypot(x-rx,z-rz)-r,0))
    for bx,bz,ax,az in ((-13.0,7.0,3.0,3.9),(12.6,1.5,2.8,3.7)):
        e=np.hypot((x-bx)/ax,(z-bz)/az); d=np.minimum(d,np.maximum(e-1,0)*min(ax,az))
    return d
def color(x,z,t=0.0):
    d=dist(x,z)+0.35*np.sin(x*1.3+z*0.9)*np.sin(z*1.1-x*0.4)
    A,B,C,D=lin("A6EBDD"),lin("8FE3D6"),lin("5CC8D0"),lin("4AA6D8")
    s=lambda a,b,v: np.clip((v-a)/(b-a),0,1)[...,None]**1*(3-2*np.clip((v-a)/(b-a),0,1)[...,None])*np.clip((v-a)/(b-a),0,1)[...,None]
    col=A+(B-A)*s(0.3,2.0,d); col=col+(C-col)*s(2.0,7.0,d); col=col+(D-col)*s(7.0,16.0,d)
    hl=np.sin(x*0.9+np.sin(z*0.7)*1.5)*np.sin(z*1.2-np.sin(x*0.5))
    col=col+(1-col)*0.10*s(0.92,0.99,hl)
    foam=s(0.0,0.12,d)*(1-s(0.45,0.75,d))
    col=col+(1-col)*0.92*foam
    return col
