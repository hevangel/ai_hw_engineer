// Icarus VPI transport only: no CPU, RAM, decoder, or video model.
#include <vpi_user.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#define PIXELS (560*192)
static FILE *keys, *resets;

static PLI_INT32 reset_call(PLI_BYTE8 *unused) {
    (void)unused;
    if (!resets) resets=fopen("work/front_panel.reset","rb");
    int c=EOF;
    if (resets) { clearerr(resets); c=fgetc(resets); }
    s_vpi_value value={.format=vpiIntVal};
    value.value.integer=c!=EOF;
    vpi_put_value(vpi_handle(vpiSysTfCall,NULL),&value,NULL,vpiNoDelay);
    return 0;
}

static PLI_INT32 key_call(PLI_BYTE8 *unused) {
    (void)unused;
    if (!keys) keys=fopen("work/front_panel.keys","rb");
    int c=EOF;
    if (keys) { clearerr(keys); c=fgetc(keys); }
    s_vpi_value value={.format=vpiIntVal};
    value.value.integer=c==EOF ? 0 : 0x100|c;
    vpi_put_value(vpi_handle(vpiSysTfCall,NULL),&value,NULL,vpiNoDelay);
    return 0;
}

static PLI_INT32 frame_call(PLI_BYTE8 *unused) {
    (void)unused;
    vpiHandle iterator=vpi_iterate(vpiArgument,vpi_handle(vpiSysTfCall,NULL));
    vpiHandle pixels=iterator ? vpi_scan(iterator) : NULL;
    if (!pixels || vpi_get(vpiSize,pixels)!=PIXELS) {
        vpi_printf("ERROR: $a2_frame requires exactly %d serialized pixels\n",PIXELS);
        vpi_control(vpiFinish,1); return 0;
    }
    if (iterator) vpi_free_object(iterator);
    s_vpi_value value={.format=vpiVectorVal};
    vpi_get_value(pixels,&value);
    unsigned char image[PIXELS];
    for (int i=0;i<PIXELS;i++) {
        uint32_t mask=UINT32_C(1)<<(i%32);
        image[i]=(value.value.vector[i/32].bval&mask) ? 2 :
            ((value.value.vector[i/32].aval&mask) ? 1 : 0);
    }
    FILE *f=fopen("work/front_panel.frame.tmp","wb");
    if (!f) { perror("front panel frame"); vpi_control(vpiFinish,1); return 0; }
    if (fwrite(image,1,sizeof image,f)!=sizeof image || fclose(f)!=0 ||
        rename("work/front_panel.frame.tmp","work/front_panel.frame")!=0) {
        perror("front panel publish"); vpi_control(vpiFinish,1);
    }
    return 0;
}

static void register_panel(void) {
    s_vpi_systf_data key={.type=vpiSysFunc,.sysfunctype=vpiIntFunc,
        .tfname="$a2_key",.calltf=key_call};
    s_vpi_systf_data frame={.type=vpiSysTask,.tfname="$a2_frame",.calltf=frame_call};
    s_vpi_systf_data reset={.type=vpiSysFunc,.sysfunctype=vpiIntFunc,
        .tfname="$a2_reset",.calltf=reset_call};
    vpi_register_systf(&key); vpi_register_systf(&frame);
    vpi_register_systf(&reset);
}
void (*vlog_startup_routines[])(void)={register_panel,NULL};
