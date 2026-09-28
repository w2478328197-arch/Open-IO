#include "reader_view.h"
#include "reader_input.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
typedef struct {const char *text;bool visible;int y;} Node;
static Node nodes[40];static unsigned used;
static bool idle(void *context){(void)context;return true;}
static void *create(void *context,void *parent){(void)context;(void)parent;assert(used<40);return &nodes[used++];}
static void *label(void *context,void *parent,unsigned font){assert(font==14||font==16||font==20);return create(context,parent);}
static void place(void *context,void *node,int x,int y,int w,int h){(void)context;(void)x;assert(w>0&&h>0);((Node *)node)->y=y;}
static void buffer(void *context,void *node,const uint8_t *bytes,unsigned w,unsigned h){(void)context;(void)node;assert(bytes&&w==64&&h==88);}
static void text(void *context,void *node,const char *value){(void)context;((Node *)node)->text=value;}
static void show(void *context,void *node,bool value){(void)context;((Node *)node)->visible=value;}
static void destroy(void *context,void *node){(void)context;(void)node;}
static void stage(WRReader *r,unsigned index){
 uint8_t *b=r->bank[r->front^1];memset(b,0,WR_BANK_BYTES);
 wr_put(b,3);wr_put(b+4,index);wr_put(b+8,3);wr_put(b+12,2);wr_put(b+16,index);wr_put(b+28,42);
 strcpy((char *)b+64,"Card title");strcpy((char *)b+160,"Project");
 strcpy((char *)b+256,"* Important fact");strcpy((char *)b+384,"Supporting fact");
 assert(wr_validate(b,512));r->active=true;r->pending=true;r->staging_revision++;
}
int main(void){
 assert(wr_input_swipe(-80,4)==1);assert(wr_input_swipe(80,-4)==-1);
 assert(wr_input_swipe(-10,0)==0);assert(wr_input_swipe(20,30)==0);assert(wr_input_swipe(0,-90)==0);
 assert(!wr_should_close_for_idle(false,90000));assert(wr_should_close_for_idle(false,90001));assert(!wr_should_close_for_idle(true,9000000));
 TNWidgets widgets={NULL,idle,create,create,label,place,buffer,text,show,destroy};
 WRReader *reader=calloc(1,sizeof *reader);WRView view={0};assert(wr_view_open(&view,&widgets,NULL));
 reader->cue_home=true;assert(wr_view_draw(&view,reader));assert(!strcmp(((Node *)view.header)->text,"提词卡"));assert(!strcmp(((Node *)view.lines[1])->text,"请在手机选择项目"));assert(!strcmp(((Node *)view.lines[2])->text,"并开始眼镜提词"));assert(strstr(((Node *)view.footer)->text,"单击翻卡"));
 reader->cue_home=false;
 stage(reader,0);assert(wr_view_draw(&view,reader));assert(reader->row==0&&!reader->automatic&&!reader->pending);
 assert(!strcmp(((Node *)view.header)->text,"Card title"));assert(strstr(((Node *)view.footer)->text,"1 / 3"));
 assert(!strcmp(((Node *)view.lines[0])->text,"* Important fact"));assert(!strcmp(((Node *)view.lines[1])->text,"Supporting fact"));
 assert(!((Node *)view.lines[4])->text[0]);for(unsigned i=0;i<4;i++)assert(!((Node *)view.cards[i])->visible);
 wr_press(reader,1000);assert(wr_view_draw(&view,reader));assert(strstr(((Node *)view.footer)->text,"换卡"));
 stage(reader,1);assert(wr_view_draw(&view,reader));assert(strstr(((Node *)view.footer)->text,"2 / 3"));
 assert(((Node *)view.lines[1])->y==28);stage(reader,2);assert(wr_view_draw(&view,reader));assert(strstr(((Node *)view.footer)->text,"最后一张"));
 assert(wr_view_close(&view));free(reader);puts("PASS cue-card rendering: title, complete points, static rows, progress, last-card boundary");
}
