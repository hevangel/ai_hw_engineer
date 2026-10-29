#!/usr/bin/env python3
"""Fetch Peter Lemon's freely distributed SNES test and demo ROMs
(github.com/PeterLemon/SNES) at a pinned git revision, together with the
reference screenshots the author published next to each ROM, and verify
every file against its git blob hash. Files land in work/roms/ only; they
never enter Git.

Download targets are compile-time constants validated against an explicit
scheme/host allowlist before any request is made.
"""
import hashlib
import urllib.parse
import urllib.request
from pathlib import Path

REPO = "PeterLemon/SNES"
REVISION = "350b394e86ec5d62f600b5cbf64cdce3721bb6ef"
ALLOWED_SCHEMES = {"https"}
ALLOWED_HOSTS = {"raw.githubusercontent.com"}

# (path in the repository, git blob sha1)
FILES = [
    ("BANK/HiROMFastROM/BANKHiROMFastROM.sfc", "fdae1c650af0d595840f5de345da191bc9bf222d"),
    ("BANK/HiROMFastROM/BANKHiROMFastROM.png", "e5df657b79d8f4a78022c66c125ec7dbc6f1c6f0"),
    ("BANK/HiROMSlowROM/BANKHiROMSlowROM.sfc", "d38b02af7dd70b5453f6baab877225040df488c2"),
    ("BANK/HiROMSlowROM/BANKHiROMSlowROM.png", "f11d17e039a54425fa07db40c5bb66a1c0cb93c5"),
    ("BANK/LoROMFastROM/BANKLoROMFastROM.sfc", "ff3db93559509129b50bf00202f946fca9facccd"),
    ("BANK/LoROMFastROM/BANKLoROMFastROM.png", "b73a6ad7533b0c8b21a2d8b5423f79d39c44f5e7"),
    ("BANK/LoROMSlowROM/BANKLoROMSlowROM.sfc", "39ff689dcafe61009267074b34bc8564e766bd19"),
    ("BANK/LoROMSlowROM/BANKLoROMSlowROM.png", "c8ed4ccaf9ad35a77b2d21d8677e4b70323f4299"),
    ("BANK/WRAM/BANKWRAM.sfc", "6fbca1db0daab5d33d250c217153e0784f95e0ca"),
    ("BANK/WRAM/BANKWRAM.png", "b1641c3a5f2727f33cf44c448cbfc6c6b9adf075"),
    ("CPUTest/CPU/ADC/CPUADC.sfc", "0e1ce85178d9ba40ad21f24c5bde58ad6d527569"),
    ("CPUTest/CPU/ADC/CPUADC.png", "cda0fa10cb7ffea8f18023720a896442eee19a83"),
    ("CPUTest/CPU/AND/CPUAND.sfc", "eb5adcce2a17d84ee7053ca0d6365389e699b86e"),
    ("CPUTest/CPU/AND/CPUAND.png", "30b48fb28d5b805f086fd6d10322bba2b2efe71b"),
    ("CPUTest/CPU/ASL/CPUASL.sfc", "2671db8bd3d53632944475074c21256ebc90205a"),
    ("CPUTest/CPU/ASL/CPUASL.png", "cee785c9390ad208759ef5caa72c93155ef1801b"),
    ("CPUTest/CPU/BIT/CPUBIT.sfc", "91c3e4ac056f8438abf3fb73c6232ee297c3cda0"),
    ("CPUTest/CPU/BIT/CPUBIT.png", "d3c97e86986ad741528a76d577481c226b8befcd"),
    ("CPUTest/CPU/BRA/CPUBRA.sfc", "655eeaa4d094cf0cbbe63be0185324c246254b49"),
    ("CPUTest/CPU/BRA/CPUBRA.png", "acbe7f733193d5b3035f653dde9b2e0bd70c73aa"),
    ("CPUTest/CPU/CMP/CPUCMP.sfc", "78236f4db474ea0c8011e7b666b472def8c58642"),
    ("CPUTest/CPU/CMP/CPUCMP.png", "8f93ae4455a4dec450fc5498c804a1a7f2233690"),
    ("CPUTest/CPU/DEC/CPUDEC.sfc", "ebbc4e5c685e29ab7488227abaab682294cc8acd"),
    ("CPUTest/CPU/DEC/CPUDEC.png", "b1cc1451554b3e25ed97d1ed03e027ddb586509a"),
    ("CPUTest/CPU/EOR/CPUEOR.sfc", "1df5d81c042732b3cb0eea7596d651a0cf65afe7"),
    ("CPUTest/CPU/EOR/CPUEOR.png", "08b30d4fdcf80473b6c1cc31c71ec806d9ce917a"),
    ("CPUTest/CPU/INC/CPUINC.sfc", "29bfc61c1c3f5bc27af2beb7b5c462c8ab8fe967"),
    ("CPUTest/CPU/INC/CPUINC.png", "e613d4b5419de02977de90b71817c7f78948fb79"),
    ("CPUTest/CPU/JMP/CPUJMP.sfc", "98bf2620d6edfd10964efdbeacf822d38b489120"),
    ("CPUTest/CPU/JMP/CPUJMP.png", "bdb95f3416f68aeb6ab183e4fe22ba87dd36f3ec"),
    ("CPUTest/CPU/LDR/CPULDR.sfc", "2e661a0c2531929841515622c2271942e299e478"),
    ("CPUTest/CPU/LDR/CPULDR.png", "095ea853a9577aec3d813198a07ecd8a5fb6bdc3"),
    ("CPUTest/CPU/LSR/CPULSR.sfc", "4ab535e766816a6caeb0782d334bdd80dd77502a"),
    ("CPUTest/CPU/LSR/CPULSR.png", "ebd60cfd16f6e1f583ff7ac13260589cbc6c39a2"),
    ("CPUTest/CPU/MOV/CPUMOV.sfc", "7e1c645131ce87faf5481ba49a8ce2620c67b5df"),
    ("CPUTest/CPU/MOV/CPUMOV.png", "a8375c193d2e38a6d80bf41a947c1761ea7215c2"),
    ("CPUTest/CPU/MSC/CPUMSC.sfc", "450d157bff484fb044ababc60736cfd834f53be2"),
    ("CPUTest/CPU/MSC/CPUMSC.png", "2d0b612c31cc58b57dee236cf75b0d37e6d244b3"),
    ("CPUTest/CPU/ORA/CPUORA.sfc", "213402b441adaccebb1a1a4aed4e4bc12a23d14e"),
    ("CPUTest/CPU/ORA/CPUORA.png", "0ce199ac3a58238a3c9484ca89d4c1c7acc1afab"),
    ("CPUTest/CPU/PHL/CPUPHL.sfc", "58d6c11a339c812446305fc10d21eb209c2dbba7"),
    ("CPUTest/CPU/PHL/CPUPHL.png", "2afc56c13df5168ed71af6ee01f67af42c01f8f1"),
    ("CPUTest/CPU/PSR/CPUPSR.sfc", "7cab054537de99754d9560dafb852a90495e1567"),
    ("CPUTest/CPU/PSR/CPUPSR.png", "87418e1e0cdce1e58644738b64b0a7ae45edbf2d"),
    ("CPUTest/CPU/RET/CPURET.sfc", "e4d0b8a00f892ca898eb26a1cdf0c0a3a51078fc"),
    ("CPUTest/CPU/RET/CPURET.png", "fac1f0dc482dc278637f0b0bdfd22e3c175a1fa5"),
    ("CPUTest/CPU/ROL/CPUROL.sfc", "09df46b51a12fe126e730f5f8a172b03b3e18482"),
    ("CPUTest/CPU/ROL/CPUROL.png", "00ff0800183a456c265389193897c658100b6c4a"),
    ("CPUTest/CPU/ROR/CPUROR.sfc", "62c9c89da8cc8167b72efb635ea7e74b23a0d85d"),
    ("CPUTest/CPU/ROR/CPUROR.png", "890d91b403a71767f44bb3c3d4136b86009f1a3a"),
    ("CPUTest/CPU/SBC/CPUSBC.sfc", "5d74af8a717ed57e359cc6059d89dadb865538db"),
    ("CPUTest/CPU/SBC/CPUSBC.png", "beb3e4d78e87be3f8a39ebb80391462da91cbf54"),
    ("CPUTest/CPU/STR/CPUSTR.sfc", "50887680338ddb48cc20af8e12aad6b719857082"),
    ("CPUTest/CPU/STR/CPUSTR.png", "3554c51a0c6a285e360fb217b8d751d9fa61ffe4"),
    ("CPUTest/CPU/TRN/CPUTRN.sfc", "5eeb05b3e4d76a7b46170a2d9b36624c3350fa77"),
    ("CPUTest/CPU/TRN/CPUTRN.png", "62b266d3ae0e46e88ad24a2df58cdddede3d5637"),
    ("CPUTest/SPC700/ADC/SPC700ADC.sfc", "35913a9072e99169900caf5c12a5b1bc9793dfd2"),
    ("CPUTest/SPC700/ADC/SPC700ADC.png", "9d74808ce390800da2af2bdf86c9c6b5bb23f782"),
    ("CPUTest/SPC700/AND/SPC700AND.sfc", "2b0efbc8956e11539ee91722f26881826114b65d"),
    ("CPUTest/SPC700/AND/SPC700AND.png", "8db51c0f7e2e03a3a77f30216fcf0dd64b4e7920"),
    ("CPUTest/SPC700/DEC/SPC700DEC.sfc", "fd9b45304c27be6d174d585de98036670e5acc04"),
    ("CPUTest/SPC700/DEC/SPC700DEC.png", "ffc9341229a13ef5fc869f6a62a910df6ce82aae"),
    ("CPUTest/SPC700/EOR/SPC700EOR.sfc", "709e9ee6e582658b21494fcb7401d0ba8cf95889"),
    ("CPUTest/SPC700/EOR/SPC700EOR.png", "661c68867d29f6b96ed5ffc231d1ee6ce7741ecf"),
    ("CPUTest/SPC700/INC/SPC700INC.sfc", "33030a6885aa5b3a9f1d3f9c73c97d4a97df4126"),
    ("CPUTest/SPC700/INC/SPC700INC.png", "8a9980b9d2f9012c120ac984991f639ffbe6ec5e"),
    ("CPUTest/SPC700/ORA/SPC700ORA.sfc", "7c84253ebfe0b8ae62e29b891da441a68dee7475"),
    ("CPUTest/SPC700/ORA/SPC700ORA.png", "bc78927fd459587860c601f9a97d855e47dccd97"),
    ("CPUTest/SPC700/SBC/SPC700SBC.sfc", "a2be7564aa648466ca36435b0c26f7c6ace285bc"),
    ("CPUTest/SPC700/SBC/SPC700SBC.png", "d7611fcde45f324c939a8a6fd2c8a988e960d18d"),
    ("HelloWorld/HelloWorld.sfc", "c59dc1e5203a6955345686e0f3aa043e8580d7e8"),
    ("HelloWorld/HelloWorld.png", "26ea18962e3946b2bcef510966adece77e60db6c"),
    ("PPU/BGMAP/8x8/2BPP/8x8BG1Map2BPP32x328PAL/8x8BG1Map2BPP32x328PAL.sfc", "259615aee4b00102c1108e58c1f540223a060c23"),
    ("PPU/BGMAP/8x8/2BPP/8x8BG1Map2BPP32x328PAL/8x8BG1Map2BPP32x328PAL.png", "685f9ddd85bafba3ad6fb414431f4c09d27346ec"),
    ("PPU/BGMAP/8x8/2BPP/8x8BG2Map2BPP32x328PAL/8x8BG2Map2BPP32x328PAL.sfc", "4b00726bd8a531c44b5b6aa7c889e6d685278109"),
    ("PPU/BGMAP/8x8/2BPP/8x8BG2Map2BPP32x328PAL/8x8BG2Map2BPP32x328PAL.png", "d49b38f03b732af85b47340f1fc4525141fe13d2"),
    ("PPU/BGMAP/8x8/2BPP/8x8BG3Map2BPP32x328PAL/8x8BG3Map2BPP32x328PAL.sfc", "05685d997c42dabac89d9bd966a15e46bbcce6b8"),
    ("PPU/BGMAP/8x8/2BPP/8x8BG3Map2BPP32x328PAL/8x8BG3Map2BPP32x328PAL.png", "d49b38f03b732af85b47340f1fc4525141fe13d2"),
    ("PPU/BGMAP/8x8/2BPP/8x8BG4Map2BPP32x328PAL/8x8BG4Map2BPP32x328PAL.sfc", "6b07b464d2567d06c38ad29e843f1143a6d41771"),
    ("PPU/BGMAP/8x8/2BPP/8x8BG4Map2BPP32x328PAL/8x8BG4Map2BPP32x328PAL.png", "d49b38f03b732af85b47340f1fc4525141fe13d2"),
    ("PPU/BGMAP/8x8/4BPP/8x8BGMap4BPP32x328PAL/8x8BGMap4BPP32x328PAL.sfc", "3bc12cbf385e39151883cd5a6427cf9077d1093b"),
    ("PPU/BGMAP/8x8/4BPP/8x8BGMap4BPP32x328PAL/8x8BGMap4BPP32x328PAL.png", "653deb0a034547d324d79cfe9f80020de045d609"),
    ("PPU/BGMAP/8x8/8BPP/32x32/8x8BGMap8BPP32x32.sfc", "a926cf7642cd61f57c4233647195d91bf0c395ab"),
    ("PPU/BGMAP/8x8/8BPP/32x64/8x8BGMap8BPP32x64.sfc", "bfdb47fc4e62e6f8ac942d57be16fc93a694797a"),
    ("PPU/BGMAP/8x8/8BPP/64x32/8x8BGMap8BPP64x32.sfc", "de52e523f16bdfa3641523e3caafb1cf511aa0fb"),
    ("PPU/BGMAP/8x8/8BPP/64x64/8x8BGMap8BPP64x64.sfc", "a7fe9b3eefeb6896884de1ff49625557e15b1e37"),
    ("PPU/BGMAP/8x8/8BPP/TileFlip/8x8BGMapTileFlip.sfc", "10486aea8e09f604ab93cae371656690ebf725e9"),
    ("PPU/BGMAP/8x8/8BPP/TileFlip/8x8BGMapTileFlip.png", "abc660c8336cd16aa6c6b6dfc8a89f572e3adc47"),
    ("PPU/Blend/HiColor/HiColor1241DLair/HiColor1241DLair.sfc", "a227edf680ec862f5f6f38516e2b3e05a60105b7"),
    ("PPU/Blend/HiColor/HiColor1241DLair/HiColor1241DLair.png", "096411b49e077c08677812f54929551ad72b5926"),
    ("PPU/Blend/HiColor/HiColor3840/HiColor3840.sfc", "455ec9f8e76bc1ae58beef3db25ad0c6e9160bd5"),
    ("PPU/Blend/HiColor/HiColor3840/HiColor3840.png", "7108ffe0de918cef4a4764ff97a20de2804f8c4d"),
    ("PPU/Blend/HiColor/HiColor575Myst/HiColor575Myst.sfc", "7a87371fdc8acae209ec05137b589650de5bc570"),
    ("PPU/Blend/HiColor/HiColor575Myst/HiColor575Myst.png", "c38b7c751918922329cd2d99792d13864c4f3369"),
    ("PPU/GreenSpace/GreenSpace.sfc", "2fcbf0c5cbfb423c1394174e940e520090d96f44"),
    ("PPU/GreenSpace/GreenSpace.png", "f9f664bc6eaf1bf68bdc2ec8961476bc32756f8a"),
    ("PPU/HDMA/HiColor128PerTileRow/HiColor128PerTileRow.sfc", "a590c5123366869d9b7ed2e09ea7dbfb8011b1c0"),
    ("PPU/HDMA/HiColor128PerTileRow/HiColor128PerTileRow.png", "8c963281fc62bc1a8772b6d9ed90e3dc2186c7d9"),
    ("PPU/HDMA/HiColor128PerTileRow/TEST/DQ128PerTileRow.sfc", "9485da8d83a7d80a6729b5f860ca364310611ce1"),
    ("PPU/HDMA/HiColor128PerTileRow/TEST/DQ128PerTileRow.png", "2d55e2a960f3eeb323049d3aab762591ab2d2608"),
    ("PPU/HDMA/HiColor128PerTileRow/TEST/RGB_24bits_palette_color_test_chart128PerTileRow.sfc", "a590c5123366869d9b7ed2e09ea7dbfb8011b1c0"),
    ("PPU/HDMA/HiColor128PerTileRow/TEST/RGB_24bits_palette_color_test_chart128PerTileRow.png", "8c963281fc62bc1a8772b6d9ed90e3dc2186c7d9"),
    ("PPU/HDMA/HiColor128PerTileRow/TEST/lenna128PerTileRow.sfc", "df496190189dfad085f4c0385de3fa63c6f38531"),
    ("PPU/HDMA/HiColor128PerTileRow/TEST/lenna128PerTileRow.png", "759ddf451e44cffd24121b53fb05c3db03f23359"),
    ("PPU/HDMA/HiColor128PerTileRow/TEST/mandrill128PerTileRow.sfc", "75f694b35b17372b8ca41fd0c7f967f4cb85bda0"),
    ("PPU/HDMA/HiColor128PerTileRow/TEST/mandrill128PerTileRow.png", "b6ba491f146920fce03f9ebc71ce4f7948eb2da6"),
    ("PPU/HDMA/HiColor64PerTileRow/HiColor64PerTileRow.sfc", "7b67c4eac648c822eaf73c92c269b16e6fe4b81d"),
    ("PPU/HDMA/HiColor64PerTileRow/HiColor64PerTileRow.png", "a275557fb236644b67e07bb54dc7bd7772bb2288"),
    ("PPU/HDMA/HiColor64PerTileRow/TEST/DQ64PerTileRow.sfc", "ef87516e95c256cb0cd38c47415f937f50df6e12"),
    ("PPU/HDMA/HiColor64PerTileRow/TEST/DQ64PerTileRow.png", "dcfa1b622cd0fa879b7d77242f37f77e2a1a578b"),
    ("PPU/HDMA/HiColor64PerTileRow/TEST/RGB_24bits_palette_color_test_chart64PerTileRow.sfc", "7b67c4eac648c822eaf73c92c269b16e6fe4b81d"),
    ("PPU/HDMA/HiColor64PerTileRow/TEST/RGB_24bits_palette_color_test_chart64PerTileRow.png", "a275557fb236644b67e07bb54dc7bd7772bb2288"),
    ("PPU/HDMA/HiColor64PerTileRow/TEST/lenna64PerTileRow.sfc", "7c6881846df61ff207df492f9ac5128302653412"),
    ("PPU/HDMA/HiColor64PerTileRow/TEST/lenna64PerTileRow.png", "d00e68f644722235c744e9d8611083392af9dd0b"),
    ("PPU/HDMA/HiColor64PerTileRow/TEST/mandrill64PerTileRow.sfc", "e9c9c6fdc08b5b3ef03e3e35d38fdf0920376828"),
    ("PPU/HDMA/HiColor64PerTileRow/TEST/mandrill64PerTileRow.png", "3296d312e737bbe6432e5d994f14a32b169c1be1"),
    ("PPU/HDMA/HiColor64PerTileRowPseudoHiRes/HiColor64PerTileRowPseudoHiRes.sfc", "90c0746ec0ff666ea0d1a5cae36de062dc1853fc"),
    ("PPU/HDMA/HiColor64PerTileRowPseudoHiRes/HiColor64PerTileRowPseudoHiRes.png", "1be76ded859907d6828d0bdff42811a5d043f68f"),
    ("PPU/HDMA/HiColor64PerTileRowPseudoHiRes/TEST/RGB_24bits_palette_color_test_chart64PerTileRowHiRes.sfc", "4e5ddda541738583cf1cc956ab5e7be96ff7b6ae"),
    ("PPU/HDMA/HiColor64PerTileRowPseudoHiRes/TEST/RGB_24bits_palette_color_test_chart64PerTileRowHiRes.png", "cb43ff6801aa4c6c30fea59d42b4e10d8a3103d2"),
    ("PPU/HDMA/HiColor64PerTileRowPseudoHiRes/TEST/lenna64PerTileRowHiRes.sfc", "104b9d68ba5223616eb2b46c7a769aaf9f3eb60d"),
    ("PPU/HDMA/HiColor64PerTileRowPseudoHiRes/TEST/lenna64PerTileRowHiRes.png", "0c76eedb023ef1c2f117e74760605b9d41afa2da"),
    ("PPU/HDMA/HiColor64PerTileRowPseudoHiRes/TEST/mandrill64PerTileRowHiRes.sfc", "90c0746ec0ff666ea0d1a5cae36de062dc1853fc"),
    ("PPU/HDMA/HiColor64PerTileRowPseudoHiRes/TEST/mandrill64PerTileRowHiRes.png", "1be76ded859907d6828d0bdff42811a5d043f68f"),
    ("PPU/HDMA/Mode7HDMA/Mode7HDMA.sfc", "e9d438d787efbde80a91fb22509f668a01b8def8"),
    ("PPU/HDMA/Mode7HDMA/Mode7HDMA.png", "4cf63f668c8a8a9490f7682059836db7570c1354"),
    ("PPU/HDMA/RedSpace9BitHDMA/RedSpace9BitHDMA.sfc", "5407723fba3546a12ca51ad493f85c88558b2f0d"),
    ("PPU/HDMA/RedSpace9BitHDMA/RedSpace9BitHDMA.png", "a0f298c93415a5c5564302e0ae2bc7d558b840bc"),
    ("PPU/HDMA/RedSpaceHDMA/RedSpaceHDMA.sfc", "6ca050cd489e106e83b6784be7550be28da931aa"),
    ("PPU/HDMA/RedSpaceIndirectHDMA/RedSpaceIndirectHDMA.sfc", "3be6a0c41fbade1a84292372e77c9ff14c74fbb4"),
    ("PPU/HDMA/WaveHDMA/WaveHDMA.sfc", "e25dfe57291cdba4f2c4121e41e9743436de2f76"),
    ("PPU/HDMA/WaveHDMA/WaveHDMA.png", "b81d94c06739168405c9be541bbf926161f8b0c5"),
    ("PPU/Interlace/InterlaceFont/InterlaceFont.sfc", "4a4b15e312868a0f03b6e51e855333835ff18619"),
    ("PPU/Interlace/InterlaceFont/InterlaceFont.png", "a40af5868550a1f4c950679c1c73c1c81a80cfb8"),
    ("PPU/Interlace/InterlaceMoogle/InterlaceMoogle.sfc", "a5aadabd716e50cd98a49a62d520648ef79a20a1"),
    ("PPU/Interlace/InterlaceMoogle/InterlaceMoogle.png", "5ace7a4b6873d72d36027cc8cba80381fab94e79"),
    ("PPU/Interlace/InterlaceMystHDMA/InterlaceMystHDMA.sfc", "463aff46fc508d03872094c270599d79a32ff489"),
    ("PPU/Interlace/InterlaceMystHDMA/InterlaceMystHDMA.png", "727e3f7add64850ebd7861f7af6da899e06af5b4"),
    ("PPU/Interlace/InterlaceRPG/InterlaceRPG.sfc", "73683638102d204d28641c7fe2d82c49cdd93d81"),
    ("PPU/Interlace/InterlaceRPG/InterlaceRPG.png", "26d4b4c68a66537e7cd2a982f02e7738ac5cbc22"),
    ("PPU/Interlace/InterlaceScroll/InterlaceScroll.sfc", "125db079911a1d1d7f07bd2dfc744acc9ad24485"),
    ("PPU/Interlace/InterlaceScroll/InterlaceScroll.png", "0fd31cb5e5423b838a12bd5c3893ffe1156ce695"),
    ("PPU/Interlace/InterlaceSimpsonsHDMA/InterlaceSimpsonsHDMA.sfc", "8de06b09034992c495b595b4861c622c8d6bb633"),
    ("PPU/Interlace/InterlaceSimpsonsHDMA/InterlaceSimpsonsHDMA.png", "768ec63dc1be6ad9f1695bffb8590acd71f536ab"),
    ("PPU/Mode7/Perspective/Perspective.sfc", "ee9c8f3014e528cdde02e02a17d29c57ca74aa73"),
    ("PPU/Mode7/Perspective/Perspective.png", "8d141c8862460f5bbdf564af570c4cac3d07db76"),
    ("PPU/Mode7/RotZoom/RotZoom.sfc", "64bd3a15e80d000907b4fe42904ed3dc10631c6f"),
    ("PPU/Mode7/RotZoom/RotZoom.png", "b8e1892b61419ab4c0c9bf5f56823a7c148d432e"),
    ("PPU/Mode7/StarWars/StarWars.sfc", "fa3b37230a8798f0939c75ea29aa28a68b7357a4"),
    ("PPU/Mode7/StarWars/StarWars.png", "97918431b8c568781a40c5d587977700e31c385e"),
    ("PPU/Mosaic/Mode3/MosaicMode3.sfc", "e4c9bff83581ae14269209a550649d13179af582"),
    ("PPU/Mosaic/Mode3/MosaicMode3.png", "e55a5a73dad33404d2d0a222304bfa58f2ec6b62"),
    ("PPU/Mosaic/Mode5/MosaicMode5.sfc", "afbea638fc5baa58df2a742cceedc4516f6826ab"),
    ("PPU/Mosaic/Mode5/MosaicMode5.png", "232ff7a32a4456c6e7146d9ecfffcfb7eb361306"),
    ("PPU/Rings/Rings.sfc", "931eae8439ca800b97c90e636f5f69209cbb4383"),
    ("PPU/Rings/Rings.png", "d02d31ebf8b5e290e4c6d203139f95aff6090074"),
    ("PPU/Window/WindowHDMA/WindowHDMA.sfc", "6ffc08d6cb0ac584000771839547e9a4a83746d1"),
    ("PPU/Window/WindowHDMA/WindowHDMA.png", "303ec580730dd24490179c7c1672f3bc246d1c3b"),
    ("PPU/Window/WindowMultiHDMA/WindowMultiHDMA.sfc", "57fc187fe8521908db6db485f7fd1cbb9ce94b5d"),
    ("PPU/Window/WindowMultiHDMA/WindowMultiHDMA.png", "8ff3195f3be1643da66431d5ce05e7048e68b3ab"),
    ("PlotLine/Mode7/PlotLineMode7.sfc", "9294adf2d82d8e0b9068799659509883339cc12d"),
    ("PlotLine/Mode7/PlotLineMode7.png", "f53a12c15deec476c36600c960c7cd6639efcf9a"),
    ("PlotPixel/Mode7/PlotPixelMode7.sfc", "b98977dac0d64487643a57fde6d615a531da9c77"),
    ("PlotPixel/Mode7/PlotPixelMode7.png", "6c28dd5d059567251ce64731b6616678295d69d6"),
    ("SPC700/Axel-F/Axel-F.sfc", "ec00e0184b67c438e1ba4be8686a72d75f8b124f"),
    ("SPC700/FFVIIPrelude/FFVIIPrelude.sfc", "8626c713925b6cfaf823b30d43d26559d630ed3d"),
    ("SPC700/ItaloTest/ItaloTest.sfc", "8a6f57d0906c6ded913b8296d959198d379698f1"),
    ("SPC700/PitchMod/PitchMod.sfc", "20c910817bc65088d28c571fc88908f3a315a311"),
    ("SPC700/PlayBRRSample/PlayBRRSample.sfc", "cc047e1e86ade5c6911dee215958b3d4e7d4d6b0"),
    ("SPC700/PlayNoise/PlayNoise.sfc", "82804d37a4b0aa4babb48902c7b58c35e5ebe503"),
    ("SPC700/PlayTwoSong/PlayTwoSong.sfc", "f3af1a253f788f6b64e86686e8fd89af49128279"),
    ("SPC700/SpeechSynth/SpeechSynth.sfc", "aa11fe3aef9017757483b2d6516a3ca4ac792ce6"),
    ("SPC700/Twinkle/Twinkle.sfc", "e781b105ef5b620b0e49087df82c9094c2c09c1c"),
]


def blob_sha1(data):
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def main():
    root = Path(__file__).resolve().parents[1] / "work" / "roms" / "peterlemon"
    for path, blob in FILES:
        dest = root / path
        if dest.exists() and blob_sha1(dest.read_bytes()) == blob:
            continue
        url = f"https://raw.githubusercontent.com/{REPO}/{REVISION}/{urllib.parse.quote(path)}"
        parts = urllib.parse.urlparse(url)
        if parts.scheme not in ALLOWED_SCHEMES or parts.hostname not in ALLOWED_HOSTS:
            raise SystemExit(f"refusing {url}")
        with urllib.request.urlopen(url, timeout=120) as response:
            data = response.read()
        if blob_sha1(data) != blob:
            raise SystemExit(f"hash mismatch for {path}")
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
    print(f"{len(FILES)} files verified in {root}")


if __name__ == "__main__":
    main()
