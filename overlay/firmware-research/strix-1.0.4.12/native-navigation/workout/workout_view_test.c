#include "nav_view.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
typedef struct{bool busy;unsigned allocations,fail_at,deleted,buffers,texts;uintptr_t objects[22];int rects[22][4];unsigned styles[22];const uint8_t *pixels;const char *strings[20];} Mock;
static bool idle(void *p){return !((Mock *)p)->busy;}
static void *create(void *p,void *parent){assert(parent);Mock *m=p;unsigned n=++m->allocations;if(n==m->fail_at)return NULL;assert(n<=22);return &m->objects[n-1];}
static void *label(void *p,void *parent,unsigned size){unsigned font=size&255u;assert(font==14||font==16||font==18||font==20||font==32);void *o=create(p,parent);if(o){Mock *m=p;m->styles[(uintptr_t *)o-m->objects]=size;}return o;}
static void place(void *p,void *o,int x,int y,int w,int h){assert(o&&x>=0&&y>=0&&x+w<=540&&y+h<=180);Mock *m=p;int *r=m->rects[(uintptr_t *)o-m->objects];r[0]=x;r[1]=y;r[2]=w;r[3]=h;}
static void buffer(void *p,void *o,const uint8_t *data,unsigned w,unsigned h){assert(o&&((w==224&&h==144)||(w==128&&h==128)));Mock *m=p;m->pixels=data;m->buffers++;}
static void text(void *p,void *o,const char *s){assert(o&&s);Mock *m=p;m->strings[m->texts++%20]=s;}
static void visible(void *p,void *o,bool v){(void)p;(void)v;assert(o);}
static void destroy(void *p,void *o){assert(o);((Mock *)p)->deleted++;}
static TNWidgets widgets(Mock *m){return (TNWidgets){m,idle,create,create,label,place,buffer,text,visible,destroy};}
static bool avail(void *p){(void)p;return true;}
static bool enter(void *p,const TNScene *s){(void)p;return s->workout;}
static bool render(void *p,const TNScene *s,bool stale){(void)s;*(bool *)p=stale;return true;}
static bool power(void *p,enum TNPower action){(void)p;(void)action;return true;}
static void leave(void *p){(void)p;}
static void dump(const char *dir,const char *name,Mock *m){
 char path[2048];snprintf(path,sizeof path,"%s/%s.pgm",dir,name);FILE *f=fopen(path,"wb");assert(f);fprintf(f,"P5\n224 144\n255\n");assert(fwrite(m->pixels,1,224*144,f)==224*144);fclose(f);
 snprintf(path,sizeof path,"%s/%s.json",dir,name);f=fopen(path,"wb");assert(f);fputs("[",f);
 for(unsigned i=0;i<20;i++){int *r=m->rects[i+2];fprintf(f,"%s{\"x\":%d,\"y\":%d,\"w\":%d,\"h\":%d,\"style\":%u,\"text\":\"%s\"}",i?",":"",r[0],r[1],r[2],r[3],m->styles[i+2],m->strings[i]);}fputs("]\n",f);fclose(f);
}
int main(int argc,char **argv){
 TNScene s={.workout=true,.mode=TN_ALWAYS,.workout_data={146,360,176,105,342000,2120,1800,3,5,0,0,"140-<155"}};
 for(unsigned fail=1;fail<=22;fail++){Mock m={.fail_at=fail};TNWidgets a=widgets(&m);TNView v={0};assert(!tn_view_open(&v,&a,&m,&s));assert(!v.open&&!v.root);}
 Mock m={0};TNWidgets a=widgets(&m);TNView v={0};assert(tn_view_open(&v,&a,&m,&s));assert(m.allocations==22&&m.buffers==1&&m.texts==20);
 assert(!strcmp(m.strings[4],"6′00″")&&!strcmp(m.strings[7],"176")&&!strcmp(m.strings[10],"1.05")&&!strcmp(m.strings[13],"3.42")&&!strcmp(m.strings[16],"212")&&!strcmp(m.strings[1],"Z3 / 5")&&!strcmp(m.strings[2],"140-<155"));
 if(argc==2)dump(argv[1],"running",&m);
 TNScene scenario=s;scenario.workout_data.heart=85;scenario.workout_data.zone=1;memset(scenario.workout_data.zone_range,0,32);strcpy(scenario.workout_data.zone_range,"<123.5");assert(tn_view_update(&v,&scenario,false));if(argc==2)dump(argv[1],"two-digit",&m);
 scenario.workout_data=(TWData){240,7200,400,500,50000000,500000,604800,9,9,0,0,">=399.5"};assert(tn_view_update(&v,&scenario,false));if(argc==2)dump(argv[1],"bounds",&m);
 scenario=s;scenario.workout_data.paused=1;scenario.workout_data.heart=scenario.workout_data.pace=scenario.workout_data.cadence=scenario.workout_data.stride_cm=TW_MISSING16;scenario.workout_data.zone=0;memset(scenario.workout_data.zone_range,0,32);assert(tn_view_update(&v,&scenario,false));if(argc==2)dump(argv[1],"paused",&m);
 assert(tn_view_update(&v,&s,true));if(argc==2)dump(argv[1],"stale",&m);
 assert(!tn_view_update(&v,NULL,false));scenario=s;scenario.workout_data.zone_count=255;assert(!tn_view_update(&v,&scenario,false));assert(tn_view_update(&v,&s,false));

 const uint8_t *first=m.pixels;uint32_t crc=tn_crc(first,224*144);m.busy=true;s.workout_data.heart=178;assert(!tn_view_update(&v,&s,false)&&crc==tn_crc(first,224*144));m.busy=false;
 for(unsigned i=0;i<1000;i++){s.workout_data.heart=100+i%100;assert(tn_view_update(&v,&s,false));}assert(m.allocations==22);
 assert(tn_view_update(&v,&s,true));assert(!strcmp(m.strings[4],"—")&&!strcmp(m.strings[16],"—")&&!strcmp(m.strings[1],"连接中")&&!strcmp(m.strings[19],"—"));assert(tn_view_close(&v)&&m.deleted==1&&!v.workout);
 Mock navMock={0};TNWidgets navWidgets=widgets(&navMock);TNScene navScene={0};assert(tn_view_open(&v,&navWidgets,&navMock,&navScene));assert(tn_view_update(&v,&navScene,false));assert(tn_view_close(&v));
 TNRuntime runtime={0};bool stale=false;TNUI ui={&stale,avail,enter,render,power,leave};uint8_t packet[128];size_t n=tw_encode(packet,sizeof packet,1,1777,1,&s.workout_data);TNReply q=tn_receive(&runtime,&ui,packet,n,1000,true);assert(q.result==TN_OK&&q.workout&&q.active);
 tn_tick(&runtime,&ui,16000);assert(runtime.stale&&stale);n=tw_encode(packet,sizeof packet,3,1777,2,NULL);q=tn_receive(&runtime,&ui,packet,n,17000,true);assert(q.result==TN_OK&&runtime.stale);
 n=tw_encode(packet,sizeof packet,2,1777,3,&s.workout_data);q=tn_receive(&runtime,&ui,packet,n,18000,true);assert(q.result==TN_OK&&!runtime.stale&&!stale);
 TNScene nav={0};n=tn_encode(packet,sizeof packet,TN_UPDATE,1777,4,&nav);q=tn_receive(&runtime,&ui,packet,n,19000,true);assert(q.result==TN_BUSY&&runtime.scene.workout);
 n=tw_encode(packet,sizeof packet,4,1777,4,NULL);q=tn_receive(&runtime,&ui,packet,n,20000,true);assert(q.result==TN_OK&&!q.active&&q.workout);uint8_t ack[32];assert(tn_reply_encode(ack,sizeof ack,q)==32&&!memcmp(ack,"TWA1",4));
 puts("PASS native workout: 84-pixel heart, separated metric geometry and real zone bounds, 22 allocation failures, 1000 atomic updates, stale masking, protocol separation, own ACK and stop");
}
