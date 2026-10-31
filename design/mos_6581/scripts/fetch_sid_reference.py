#!/usr/bin/env python3
"""Fetch and verify the unchanged reSIDfp engine pinned in MAME's 3rdparty tree.

reSIDfp (libsidplayfp project) is GPL-2.0-or-later. It is used only as a
test oracle: the sources are downloaded into ignored work/reference, built
there, and never committed or linked into the RTL. A cached file with an
unexpected digest is rejected, never overwritten.
"""
from pathlib import Path
import hashlib
import urllib.request

REVISION = "41a494b6ef80adc924ccb2bdba1ee69580276e0c"
BASE = f"https://raw.githubusercontent.com/mamedev/mame/{REVISION}/3rdparty/residfp/"
ROOT = Path(__file__).resolve().parents[1] / "work/reference"
FILES = {
    "AUTHORS": "4056269080affa223368d11d7909c5b1f55aad9648ebb899883c6ce39b673372",
    "COPYING": "8177f97513213526df2cf6184d8ff986c675afb514d4e68a404010521b880643",
    "Dac.cpp": "a96e9a23735e8577eeaef77e704968c65c37797c311c44bd2037fa653f91c50c",
    "Dac.h": "e4b3c70850608006dc7a476852446f1b404b237e6a1ce4867fa176207adf896b",
    "EnvelopeGenerator.cpp": "a7fd4a7bb9e46a89cb00c9f2042fb4f483ef12c08dd665e21cd8d84335df621c",
    "EnvelopeGenerator.h": "43eab9e80676351227599c7d6abcff15252d46b937fab71a942d9d143c19bed9",
    "ExternalFilter.cpp": "9b8cef9f4832b5f36187e4ac3adaa6368ac9dc3afa99f5282a19a50dd72377aa",
    "ExternalFilter.h": "25a162002378fdefaf67bd37d77f97bf40fb209798639859cb143d862dbc01d3",
    "Filter.cpp": "c5c91ae83413b114f835e1ac92414603bfd1bb79e3050a896f2b4c02a2507f65",
    "Filter.h": "c33e8b5803a0caba4514e387125f620aeaa31ed6e8fe46f919bfdafb4583589c",
    "Filter6581.cpp": "77ee7acfacde7dfad6a1eeb976f0576a2b3693244a270480df9e2e24f3aca353",
    "Filter6581.h": "1a64ef9de1e98439296ddb8728274ee8c92e00887b3143f4f0d5a34a78afb099",
    "Filter8580.cpp": "9daad5d28b19022a4dabe0163bdab10e0b984556f4b834778e72c61d49063997",
    "Filter8580.h": "9513ec81a09b148f837ced8f31934fe54bb6c573fc68ba447e10e8b0542121ec",
    "FilterModelConfig.cpp": "47d87616f0e43aa1843aa3509e0eb2c8182df523ece003629e1ae06fc2b26430",
    "FilterModelConfig.h": "bf4e336ce65fb6e0e3ba367f26aac44e64755c1a6d179107aec44da8ad6b11c7",
    "FilterModelConfig6581.cpp": "39bff76d15d957288118aeb4729b788e37a2bd9f70dcde2d8b22eee287229bea",
    "FilterModelConfig6581.h": "6a81b240202bc071badd85c731992b4e56a4fa7a1c965b067d040ada29e01c8f",
    "FilterModelConfig8580.cpp": "5c5540068ebbdadc3c6685b7b4ef727ba228b5445000d6f6f3483cee49df3e6f",
    "FilterModelConfig8580.h": "cfbdb260a093c05a68267f0f2c239912b1e0c0325a8d730c3ef464fe8ffcff97",
    "Integrator.h": "05c152e896fd0508a4008d70434a06971a419cd907836b20ba8467f3ba6a703c",
    "Integrator6581.cpp": "e59e2e461f4660db06b1d1c400dcca9d6e41d559e51668a9dfdd0cda6162c42b",
    "Integrator6581.h": "6b604f8f4e261f6f15ed0cc3e8b7b1fa4a2f3645f09e2705470726aeb166831b",
    "Integrator8580.cpp": "ba779f697d00e904e31f3d29b161561b890f49d90f2211eb58f840aac09a0662",
    "Integrator8580.h": "347851c3194188976f78914fc0aaff8a3c0f39312b8f6ae74d79badce765178d",
    "OpAmp.cpp": "f9598b191414d25698341b891b5040f1b910b0b204944fef429dd80765009182",
    "OpAmp.h": "0e30e5c57e014afa82d0ed13b56a652176d967259a7c2b70d95a4ea667ab25bc",
    "README.md": "988ea9c6a9aaaac03dd827f14cde6aa039bed7272903d96cad0d4b720d6002c4",
    "SID.cpp": "7e7db0877f9dd42ee36a5b6605a469f3ff8ebc389e2f7d8a023dd2a3dd41d0da",
    "SID.h": "d39f9797cd10328406a613bd55bce9121806d38c6ff459ac76ee93e70ac02ac1",
    "Spline.cpp": "8ee079dfc56eb820e8cd99602462d008e24cdc4e948584cb8cb003adcd8faaab",
    "Spline.h": "e8ff92fb536824e48c5961a1fab47b234b55ec2a867d2a40b06fe11ed0595c7e",
    "State.cpp": "4c24471e730d0dfa614a2b05b99fcd876ac5d2f6755af90e70def0cef14791e9",
    "State.h": "4caa68f69e28cd5bbc2be7968f70542acd238a5f39e1375d3e4a5f4b7bf3fe0c",
    "Voice.h": "47b5c84addbd6eb40d3365838add509ba31ba85304bf97279ce3ba4d7111870e",
    "WaveformCalculator.cpp": "5eb72ad2d3f4e2b1e33ab4e29d5d216ccf649f104c5781aad8a9a4fe24a6fa08",
    "WaveformCalculator.h": "bb47d564a1a514086ae29cb66b77d161568691e794ac85fde07e06a3bb2c0e75",
    "WaveformGenerator.cpp": "c959bae5d1844df1b9d9ee5b2e964058c3ad527fff07122774ca88dd7bc34ec2",
    "WaveformGenerator.h": "d99c1c82f643400beffb39676365e8e4db05247f0de23a603d63a63b9d292cdf",
    "array.h": "1fd8b21d049704a9e9987cf7960b7f98a4998d448be34b761bbddb9ebcbdbdfa",
    "resample/Limiter.h": "23a9cedc31ca09aada149332f9a27f68835b098e9bd712c82d2f93720cc8f06e",
    "resample/PassThrough.h": "72c94fd8ca1cc08f7df6c651d8b4044012426c23c40557f0a2dd6e2062c6efd5",
    "resample/Resampler.h": "ebb3320734dabd6b981356c4c6a651ca217df2fffd50478a6831b39003b90b70",
    "resample/SincResampler.cpp": "f642435899c0f79aa6cdccb56951857cf83d4ecb07e79504fa9f7c3497860321",
    "resample/SincResampler.h": "883e483c06871c95752c161f99b8fb72353345487ea778602b8ee25764db899c",
    "resample/TwoPassSincResampler.h": "2a0b31cfaaebe748495512342c9e76f601bcaaf5b5303c448123caec14a4d503",
    "resample/ZeroOrderResampler.h": "3220aec48f84b222a4600184cee639aac2cfc97300dbbf148db7deb0fd59c635",
    "residfp/residfp_defs.h": "06cfdcd171c0c4f89fdd9349f613db2f198c9ce9af0f0395e8175885e0bbc73e",
    "residfp/sidversion.h": "37e6b1aec5b93354cb71f70f3c0dbc29a7f4d4755262951c8fd4f80f7143b797",
    "siddefs-fp.h": "58a1d3a89a346b0374ad52fbe6d96c356b8b8896d7eae389b661b214d6cceba1",
    "version.cc": "b0b1dcbd8f53e885b52a50382e199dc9b8f59da2015c9ec0175b510a3add5669",
}


def main():
    for name, expected in FILES.items():
        path = ROOT / name
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            data = path.read_bytes()
        else:
            with urllib.request.urlopen(BASE + name, timeout=60) as response:
                data = response.read()
        if hashlib.sha256(data).hexdigest() != expected:
            raise SystemExit(f"reSIDfp reference hash mismatch: {name}")
        if not path.exists():
            path.write_bytes(data)
    print(f"Verified {len(FILES)} unchanged reSIDfp files from MAME {REVISION}")


if __name__ == "__main__":
    main()
