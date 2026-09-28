#include "workout_wire.h"
#include <assert.h>
#include <stdio.h>
int main(void){uint8_t p[TW_PACKET_BYTES];TWData d={146,360,176,105,342000,2120,1800,3,5,0,0,"140.25-<155.75"},r;
 assert(sizeof(TWData)==TW_DATA_BYTES);
 assert(tw_encode(p,sizeof p,1,111,1,&d)==TW_PACKET_BYTES&&tw_packet_valid(p,sizeof p));assert(tw_decode_data(&r,p+32,TW_DATA_BYTES)&&r.heart==146&&r.distance_cm==342000&&!strcmp(r.zone_range,d.zone_range));
 for(unsigned i=0;i<sizeof p;i++){p[i]^=1;assert(!tw_packet_valid(p,sizeof p));p[i]^=1;}
 assert(!tw_packet_valid(p,sizeof p-1));p[4]=1;tw_p32(p+20,tw_crc(p,sizeof p,true));assert(!tw_packet_valid(p,sizeof p));
 assert(tw_encode_menu_start(p,sizeof p,111,1,&d,789)==TW_PACKET_BYTES&&tw_packet_valid(p,sizeof p)&&tw_u32(p+24)==789);
 p[5]=2;tw_p32(p+20,tw_crc(p,sizeof p,true));assert(!tw_packet_valid(p,sizeof p));
 assert(!tw_encode_menu_start(p,sizeof p,111,1,&d,0));
 d.zone=6;assert(!tw_data_valid(&d));d.zone=0;assert(!tw_data_valid(&d));memset(d.zone_range,0,sizeof d.zone_range);d.heart=TW_MISSING16;assert(tw_data_valid(&d));d.paused=1;assert(!tw_data_valid(&d));d.pace=d.cadence=d.stride_cm=TW_MISSING16;assert(tw_data_valid(&d));
 assert(tw_encode(p,sizeof p,4,111,2,NULL)==32&&tw_packet_valid(p,32));memcpy(p,"TNV1",4);assert(!tw_packet_valid(p,32));
 d=(TWData){146,360,176,105,342000,2120,1800,3,5,0,0,"140-<155"};memset(d.zone_range,'1',sizeof d.zone_range);assert(!tw_data_valid(&d));
 memset(d.zone_range,0,sizeof d.zone_range);memcpy(d.zone_range,"140\n155",7);assert(!tw_data_valid(&d));
 memset(d.zone_range,0,sizeof d.zone_range);memcpy(d.zone_range,"<125",4);d.zone_range[10]='1';assert(!tw_data_valid(&d));
 // Deterministic malformed frames, under ASan/UBSan. No caller-selected length can escape the fixed wire parser.
 uint32_t seed=0x74696f;for(unsigned j=0;j<20000;j++){for(unsigned i=0;i<sizeof p;i++){seed=1664525u*seed+1013904223u;p[i]=(uint8_t)(seed>>24);}assert(!tw_packet_valid(p,j%(sizeof p+1)));}
 puts("PASS TWK1 v2: exact bounds, 88-byte CRC, old-version rejection, missing/paused fields and 20000 malformed frames");
}
