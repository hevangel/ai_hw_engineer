#pragma once
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>
// External magnetic storage only. Commands, sector IDs, ECC, DMA and IRQs
// are interpreted by model30_fixed_disk.sv, never by this backing store.
class HardDiskMedia {
public:
    static constexpr unsigned SECTORS=612*4*17, BYTES=SECTORS*512, META_BYTES=SECTORS*12;
    static constexpr unsigned BUNDLE_BYTES=8+BYTES+META_BYTES+8;
    std::vector<uint8_t> data=std::vector<uint8_t>(BYTES,0);
    std::vector<uint8_t> metadata=std::vector<uint8_t>(META_BYTES,0);
    bool present=true,dirty=false;
    uint64_t reads=0,writes=0;
    std::string persistent_path;
    HardDiskMedia(){
        present=std::getenv("IBM_PS2_MODEL30_NO_HDD")==nullptr;
        canonical_ids();
        if(const char *path=std::getenv("IBM_PS2_MODEL30_HDD_PATH")){
            persistent_path=path;
            if(std::ifstream(path,std::ios::binary))mount(path);
        }
    }
    static uint64_t checksum(const std::vector<uint8_t> &a,const std::vector<uint8_t> &b){
        uint64_t hash=14695981039346656037ull;
        for(auto value:a){hash^=value;hash*=1099511628211ull;}
        for(auto value:b){hash^=value;hash*=1099511628211ull;}
        return hash;
    }
    void canonical_ids(){
        std::fill(metadata.begin(),metadata.end(),0);
        for(unsigned sector=0;sector<SECTORS;++sector){
            unsigned cylinder=sector/(4*17),head=(sector/17)%4,base=sector*12;
            metadata[base]=uint8_t((head<<4)|(cylinder>>8));
            metadata[base+1]=uint8_t(cylinder);metadata[base+2]=uint8_t(sector%17+1);
            metadata[base+3]=2;
        }
    }
    void mount(const std::string &path){
        std::ifstream file(path,std::ios::binary);
        std::vector<uint8_t> image{std::istreambuf_iterator<char>(file),{}};
        if(!file && image.empty())throw std::runtime_error("cannot read hard disk image");
        if(image.size()==BYTES){data=std::move(image);canonical_ids();}
        else if(image.size()==BUNDLE_BYTES && std::equal(image.begin(),image.begin()+8,"M30DISK1")){
            std::vector<uint8_t> payload(image.begin()+8,image.begin()+8+BYTES);
            std::vector<uint8_t> fields(image.begin()+8+BYTES,image.end()-8);
            uint64_t expected=0;
            for(unsigned i=0;i<8;++i)expected|=uint64_t(image[image.size()-8+i])<<(i*8);
            if(checksum(payload,fields)!=expected)throw std::runtime_error("hard disk bundle checksum mismatch");
            data=std::move(payload);metadata=std::move(fields);
        }else throw std::runtime_error("use a type-26 raw image or complete M30DISK1 bundle");
        dirty=true;
    }
    uint8_t read(unsigned sector,unsigned offset)const{
        if(sector>=SECTORS || offset>522)return 255;
        return offset<512 ? data[sector*512+offset]:metadata[sector*12+offset-512];
    }
    bool check_valid(unsigned sector)const{return sector<SECTORS && metadata[sector*12+11]!=0;}
    void write(unsigned sector,unsigned offset,uint8_t value){
        if(sector>=SECTORS || offset>522)throw std::runtime_error("RTL hard disk media address out of range");
        if(offset<512)data[sector*512+offset]=value;
        else metadata[sector*12+offset-512]=value;
        if(offset==522)metadata[sector*12+11]=1;
        dirty=true;++writes;
    }
    void save(const std::string &path,bool bundle)const{
        std::ofstream file(path,std::ios::binary|std::ios::trunc);
        if(bundle)file.write("M30DISK1",8);
        file.write(reinterpret_cast<const char*>(data.data()),data.size());
        if(bundle){
            file.write(reinterpret_cast<const char*>(metadata.data()),metadata.size());
            uint64_t hash=checksum(data,metadata);
            for(unsigned i=0;i<8;++i)file.put(char(hash>>(8*i)));
        }
        file.flush();
        if(!file)throw std::runtime_error("cannot export hard disk image");
    }
    void persist(){
        if(!dirty || persistent_path.empty())return;
        std::string temporary=persistent_path+".next";
        save(temporary,true);
        if(std::rename(temporary.c_str(),persistent_path.c_str()))throw std::runtime_error("cannot publish hard disk bundle");
        dirty=false;
    }
};
