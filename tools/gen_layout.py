import json
N=[]
def add(**k): N.append(k)
W=[0.62,0.42,0.26]; DW=[0.52,0.36,0.22]
# 码头：海盗套件平台拼成 L 形
for x in (-7.5,-5,-2.5,0,2.5,5,7.5,10):
    for z in (6,8.5):
        add(m="pirate_structure_platform",p=[x,-0.25,z],tint=[0.85,0.72,0.6],tex="wood")
for z in (3.5,1.0): add(m="pirate_structure_platform",p=[9.0,-0.25,z],tint=[0.85,0.72,0.6],tex="wood")
# 前沿木桩 + 绳子
for x in (-8.6,-6,-3.4,-0.8,1.8,4.4):
    add(k="cyl",size=[0.18,1.9],c=DW,p=[x,0.8,4.75],foam=0.9)
    add(k="cyl",size=[0.24,0.12],c=[0.86,0.75,0.55],p=[x,1.45,4.75])
add(k="box",size=[13.0,0.07,0.07],c=[0.86,0.75,0.55],p=[-2.1,1.3,4.75])
for z in (-0.2,2.2): add(k="cyl",size=[0.18,1.9],c=DW,p=[7.75,0.8,z]); add(k="cyl",size=[0.18,1.9],c=DW,p=[10.25,0.8,z])
# 石板路地面
for x in range(-10,11,1):
    for z in (10.3,11.2,12.1):
        add(m="nature_path_stone",p=[x+(0.5 if z==11.2 else 0),0.68,z],s=[1.05,1,1.6],tint=[0.85,0.8,0.72],tex="stone")
add(k="box",size=[22,1.4,3.6],c=[0.55,0.52,0.48],p=[0,0,11.2])
# 鱼市场小屋
M0=len(N)
H=[-5.2,0.68,7.3]
add(k="box",size=[3.6,2.4,2.6],c=[0.98,0.93,0.82],p=[H[0],H[1]+1.2,H[2]])
for dx in (-1.8,1.8):
    for dz in (-1.3,1.3): add(k="box",size=[0.25,2.5,0.25],c=DW,p=[H[0]+dx,H[1]+1.25,H[2]+dz])
add(m="pirate_structure_roof",p=[H[0],H[1]+0.0,H[2]],s=[1.35,1.0,1.0],tint=[1.05,0.95,0.75])
add(k="box",size=[1.3,0.9,0.08],c=[0.55,0.80,0.95],p=[H[0]-0.8,H[1]+1.5,H[2]+1.31])
add(k="box",size=[3.4,0.8,0.7],c=[0.62,0.45,0.30],p=[H[0],H[1]+0.4,H[2]+1.7])  # 摊位
for i in range(8):
    add(k="box",size=[0.46,0.06,1.0],c=([1,0.82,0.3] if i%2==0 else [1,1,0.97]),p=[H[0]-1.61+i*0.46,H[1]+2.25,H[2]+1.75],rx=-25)
add(k="box",size=[2.3,0.8,0.12],c=[0.55,0.36,0.2],p=[H[0],H[1]+3.2,H[2]+1.2])  # 招牌板（文字在 Swift）
add(m="survival_fish",p=[H[0]-0.6,H[1]+0.82,H[2]+1.7],s=3.5)
add(m="survival_fish",p=[H[0]+0.3,H[1]+0.82,H[2]+1.8],s=3.5,ry=30)
add(m="survival_box_large",p=[H[0]+1.0,H[1]+0.8,H[2]+1.7],s=2.2,ry=90)
add(m="nature_plant_bushLarge",p=[H[0]-2.3,H[1],H[2]+1.5],s=3)
# 摊位杂物：挂鱼、蔬菜箱
for j,dx in enumerate((-1.3,-0.7,-0.1,0.5,1.1)):
    add(k="cyl",size=[0.015,0.35],c=[0.9,0.85,0.7],p=[H[0]+dx,H[1]+1.95,H[2]+2.05])
    add(m="survival_fish",p=[H[0]+dx,H[1]+1.45,H[2]+2.05],s=4.5,rx=0,ry=90,tint=[1,1,1] if j%2 else [0.75,0.85,1.1])
for (dx,dz) in ((-2.6,2.6),(-1.6,3.0),(2.4,2.4)):
    add(m="pirate_crate",p=[H[0]+dx,H[1],H[2]+dz],s=0.55,tex="wood")
    for (ex,ez) in ((-0.15,-0.1),(0.15,0.12),(0,0.05)):
        add(m="nature_plant_bushLarge",p=[H[0]+dx+ex,H[1]+0.42,H[2]+dz+ez],s=1.6,tint=[0.8,1.1,0.6])
add(m="survival_box_large",p=[H[0]-1.0,H[1]+0.8,H[2]+1.75],s=2.0,ry=90,tex="wood")
add(m="nature_flower_redA",p=[H[0]-1.0,H[1]+1.05,H[2]+1.75],s=2.5)
# 整体放大鱼市场（以 H 为基点）
MS=1.3
for n in N[M0:]:
    n["p"]=[H[i]+(n["p"][i]-H[i])*MS for i in range(3)]
    s=n.get("s",1); n["s"]=[v*MS for v in s] if isinstance(s,list) else s*MS
# 码头上站着的小熊船长
add(prefab="bear",p=[2.2,0.68,7.0],ry=27,s=1.7)
# 码头杂物
add(m="pirate_barrel",p=[9.4,0.68,0.8],s=0.75)
add(m="pirate_crate",p=[8.5,0.68,2.6],s=0.9,ry=10)
add(m="pirate_crate",p=[8.6,1.37,2.6],s=0.75,ry=-15)
add(m="pirate_crate_bottles",p=[9.7,0.68,3.6],s=0.8)
add(m="survival_bucket",p=[2.2,0.68,6.0],s=3)
add(m="survival_barrel",p=[-1.0,0.68,8.6],s=3.2)
add(k="box",size=[1.2,1.4,0.1],c=[0.25,0.32,0.30],p=[0.8,1.4,7.4],rx=-12)  # 今日渔获黑板
add(k="box",size=[1.35,1.55,0.08],c=DW,p=[0.8,1.4,7.35],rx=-12)
# 路灯
add(k="cyl",size=[0.1,2.6],c=[0.3,0.25,0.22],p=[10.6,2.0,4.9])
add(k="box",size=[0.45,0.55,0.45],c=[1,0.85,0.4],p=[10.6,3.5,4.9],glow=1)
# 礁石 + 植物
def rock(m,x,z,s,ry=0,plants=False):
    add(m=m,p=[x,-0.6,z],s=s,ry=ry,tint=[1.35,1.02,0.72],foam=s*2.2)
    if plants:
        top=[x,-0.6+s*2.4,z]
        for (dx,dz,mm,ss) in [(0,0,"nature_plant_bushLarge",5),(-0.6,0.5,"nature_flower_yellowA",6),(0.5,0.6,"nature_flower_yellowA",6),(0.7,-0.3,"nature_plant_bush",4),(-0.5,-0.4,"nature_grass_large",4)]:
            add(m=mm,p=[top[0]+dx*s,top[1]-0.3,top[2]+dz*s],s=ss*s*0.5)
rock("pirate_rocks_a",-9,-12,1.0,30)
rock("pirate_rocks_c",-10,-3,0.85,0)
rock("pirate_rocks_c",7,-8,1.1,200,True)
rock("pirate_rocks_b",8.5,-19,0.7,90)
# 沙滩：码头前方/左前方的柔和沙滩，缓坡入水
SAND=[0.98,0.90,0.72]; SAND2=[1.0,0.94,0.80]
for (x,z,rx,rz) in ((-9.5,10.5,4.2,3.6),(-3.0,14.2,7.5,2.6),(5.5,14.4,6.0,2.4),(12.6,1.5,3.2,4.2)):
    add(k="sphere",size=[1.0],c=SAND,p=[x,-0.6,z],s=[rx,1.25,rz])
    add(k="sphere",size=[1.0],c=SAND2,p=[x,-0.5,z],s=[rx*0.8,1.22,rz*0.75])
for (m,x,z,ry,sc) in (("pirate_palm_detailed_bend",-10.8,9.6,70,1.1),("pirate_palm_detailed_straight",-12.0,12.0,0,1.0),
                      ("pirate_palm_detailed_bend",-5.5,14.6,150,0.95),("pirate_palm_detailed_bend",12.2,0.0,220,1.0),
                      ("pirate_palm_detailed_straight",13.2,3.2,0,0.95),("pirate_palm_detailed_straight",4.0,14.8,0,0.85)):
    add(m=m,p=[x,0.5,z],ry=ry,s=sc)
for (x,z) in ((-8.6,11.8),(-1.0,14.6),(7.5,14.4),(-11.5,9.0)):
    add(m="nature_plant_bushLarge",p=[x,0.5,z],s=4.5)
    add(m="nature_flower_yellowA",p=[x+0.5,0.5,z+0.4],s=5)
# 浮标
for i,(x,z) in enumerate([(-5.5,-1.0),(4.5,-9.0),(-4,-16)]):
    add(m="watercraft_buoy_flag" if i%2 else "watercraft_buoy",p=[x,0,z],s=0.6,bob=1)
NAVY=[0.16,0.24,0.5]; FUR=[0.86,0.62,0.38]; LIGHT=[0.99,0.88,0.72]; BLK=[0.1,0.08,0.08]; PINK=[0.95,0.65,0.6]
bear=[dict(k="sphere",size=[0.38],c=NAVY,p=[0,0.38,0],s=[1,1.05,0.92]),
      dict(k="box",size=[0.06,0.5,0.02],c=[1,0.85,0.3],p=[0,0.42,0.35]),
      dict(k="sphere",size=[0.13],c=FUR,p=[-0.36,0.45,0.12]),dict(k="sphere",size=[0.13],c=FUR,p=[0.36,0.45,0.12]),
      dict(k="sphere",size=[0.44],c=FUR,p=[0,1.02,0],s=[1.06,0.95,1]),
      dict(k="sphere",size=[0.15],c=FUR,p=[-0.33,1.36,-0.02]),dict(k="sphere",size=[0.15],c=FUR,p=[0.33,1.36,-0.02]),
      dict(k="sphere",size=[0.08],c=PINK,p=[-0.33,1.37,0.08]),dict(k="sphere",size=[0.08],c=PINK,p=[0.33,1.37,0.08]),
      dict(k="sphere",size=[0.19],c=LIGHT,p=[0,0.93,0.33],s=[1.1,0.8,0.75]),
      dict(k="sphere",size=[0.065],c=BLK,p=[0,0.99,0.47],s=[1.2,0.8,1]),
      dict(k="sphere",size=[0.042],c=BLK,p=[-0.16,1.1,0.39]),dict(k="sphere",size=[0.042],c=BLK,p=[0.16,1.1,0.39]),
      dict(k="sphere",size=[0.06],c=[1,0.6,0.55],p=[-0.27,0.97,0.33],s=[1,0.6,0.5]),dict(k="sphere",size=[0.06],c=[1,0.6,0.55],p=[0.27,0.97,0.33],s=[1,0.6,0.5]),
      dict(k="cyl",size=[0.38,0.2],c=[1,1,1],p=[0,1.45,-0.02]),
      dict(k="cyl",size=[0.39,0.08],c=NAVY,p=[0,1.36,-0.02]),
      dict(k="box",size=[0.44,0.04,0.22],c=NAVY,p=[0,1.33,0.34]),
      dict(k="sphere",size=[0.06],c=[1,0.8,0.2],p=[0,1.4,0.38])]
cabin=[dict(k="box",size=[1.05,0.85,0.8],c=[0.98,0.95,0.86],p=[0,0.85,-0.75]),
       dict(k="box",size=[1.25,0.12,1.0],c=[0.2,0.38,0.75],p=[0,1.33,-0.75],name="accent"),
       dict(k="box",size=[0.5,0.36,0.04],c=[0.55,0.82,0.96],p=[0,0.92,-0.33])]
boat=[dict(m="watercraft_boat_row_large",p=[0,0,0],s=[0.85,1,1.1],tint=[1,0.95,0.9])]+cabin+[dict(prefab="bear",p=[0,0.25,0.45],ry=0,s=1.25)]
L=dict(camera=dict(pos=[14,30,28],look=[-2,0,-1],fov=42),sunDir=[-0.45,-0.85,-0.35],
       prefabs=dict(bear=bear,boat=boat),nodes=N)
json.dump(L,open("/workspace/FishingIdle/App/Resources/PortLayout.json","w"),indent=0)
