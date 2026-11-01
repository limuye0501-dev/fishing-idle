import os,sys,json,base64,urllib.request
K=open(os.path.expanduser('~/.secrets/meshy_api_key')).read().strip()
B='https://api.meshy.ai/openapi'
def req(path,data=None):
    r=urllib.request.Request(B+path,data=json.dumps(data).encode() if data else None,headers={'Authorization':'Bearer '+K,'Content-Type':'application/json'})
    return json.load(urllib.request.urlopen(r))
if __name__=='__main__':
    cmd=sys.argv[1]
    if cmd=='bal': print(req('/v1/balance'))
    elif cmd=='new':
        img,poly=sys.argv[2],int(sys.argv[3])
        uri='data:image/jpeg;base64,'+base64.b64encode(open(img,'rb').read()).decode()
        print(req('/v1/image-to-3d',{'image_url':uri,'should_texture':True,'enable_pbr':False,'should_remesh':True,'target_polycount':poly,'ai_model':'latest'}))
    elif cmd=='get':
        t=req('/v1/image-to-3d/'+sys.argv[2]); print(t.get('status'),t.get('progress'),t.get('model_urls',{}).keys() if t.get('model_urls') else '', t.get('task_error'))
        if t.get('status')=='SUCCEEDED':
            for k in ('glb','usdz'):
                if t['model_urls'].get(k): urllib.request.urlretrieve(t['model_urls'][k],sys.argv[3]+'.'+k)
