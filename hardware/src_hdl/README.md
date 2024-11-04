## List of Files
Total       90 files
Coded       90 files
Checked     90 files

### ALU
- AddLogic.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Wrapper module for IntAdd.sv and Logic.sv
- ALU.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    ALU top module
- IntAdd.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Integer Adder
- IntDataPath
    Coded: Yes, Checked: Yes, Tested: Yes

    Wrapper module for AddLogic.sv and MultShift.sv
- IntMult.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Integer Multiplier
- Logic.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Logic Operations
- MultShift.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Wrapper module for IntMult.sv and Shift.sv
- Shift.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Shifter

### Common
- AttributeDec.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Attribute Word Decoder
- Buff.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Ordinary Buffer
- BuffEn.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Buffer used in Link Element
- ConfigDec_RAM.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Retime Configuration Data Decoder
- TokenDec.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Token Decoder
- TornamentL.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Large Number Tornament top module
- TornamentL4.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Large Number Tornament 4-entry
- TornamentW.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Small Number Tornament top module
- TornamentW4.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Small Number Tornament 4-entry

### CRAM
- AddrGenUnit_Ld.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Address Generation Unit for Load unit
- AddrGenUnit_St.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Address Generation Unit for Store unit
- CRAM_St_CTRL.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Store Unit Controller
- CRAM_St.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Store Unit top module
- CRAMCondUnit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Condition Handler
- Ld_BackEnd_CTRL_Block.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Sub-Controller for Load Unit Backend
- Ld_BackEnd_CTRL_Load.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Sub-Controller for Load Unit Backend
- Ld_BackEnd_CTRL.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Main-Controller for Load Unit Backend
- Ld_BackEnd.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Load Unit Backend top module
- Ld_FrontEnd_CTRL.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Controller for Load Unit Frontend
- Ld_FrontEnd.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Load Frontend top module
- LdUnit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Load Unit top module
- RConfig.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    RE-Configuration Data Storage
- ReLdStUnit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Retime Element Load/Store Unit top module

### DRoute: **EXTENSION**
- RouteGen.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Dynamic Routing module

### ElectronNest (Top)
- ComputeTile.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Grid Array top module
- ElectronNest.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Top module

### IComp: **EXTENSION**
- IndexMem.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Index Data Memory and its Controller
- MFA_CfgGen.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    MFA Configuration Data Generator
- MFA_CRAM.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    MFA Top module
- MFA_CTRL.sv
    Coded: Yes, Checked: Yes, Tested: Yes
    MFA Controller
- MFA.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    MFA Search top module
- MFAUnit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    MFA unit for one level
- OutBuff.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Output buffer (Reorder Buffer)
- OutBuffCTRL.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Buffer Controller
- OutputBuffCTRL.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Buffer Controller
- SkipIF.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Skip to execute controller
- SkipInit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Initialization controller for Skip (shared data)
- SyncUnit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Synchronization controller
- TagCam.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    CAM for Tag used in reorder buffer

### IFUnit
- BRAM_AGU.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Address Generation Unit for Buffer RAM
- BRAM.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Buffer RAM Top module
- Commit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Commit Srvice unit
- EMEM_IF.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    External memory-access unit top module
- FanInTree.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Tornament-tree for network request
- IDec.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Netowrking Request Instruction
- IFLogic.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Interfacing logic between IF Unit and Grid Array (ComputeTile.sv)
- IFPattern.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Networking Pattern Checker
- IFUnit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Interface unit top module
- LdStUnit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Load/Store Unit top module for External Memory-Access
- PortMap.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Port-Mapper unit
- RenameUnit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Port-Rename unit

### LE
- FanIn_Buff.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Buffer for FanIn Link unit
- FanIn_FIFO.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    FanIn Link for Input
- FanIn_Link.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    FanIn Link top module
- FanOut_BackEnd.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    FanOut Link Backend top module
- FanOut_CTRL.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    FanOut Link Backend Controller
- FanOut_FrontEnd.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    FanOut Frontend module
- FanOut_Link.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    FanOut Link top module
- LEBuff.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Buffer used in Link unit
- LECondUnit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Condition Handler for FanIn Link unit

### Packages
- pkg_alu.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Package for ALU
- pkg_bram_if.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Package for Interface(IF) Unit and Buffer RAM
- pkg_en.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Main Package
- pkg_extend_index.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Package for Index-Compression (EXTENSION)
- pkg_link.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Package for Link Element
- pkg_mem.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Package for Memory

### PE
- PE.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Processing Element top module

### RE
- CRAM.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Retime Element Core top module
- RE.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Retime Element top module

### Retime
- DReg.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Data Register
- TokenUnit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    TinyCTRL

### Sync
- PortSync.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Synchronization Controller on Port
- WaitUnit.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Wait Unit for Single-Stage ALU

### Util
- AdderTree.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Adder-tree unit
- Arbiter.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Arbiter unit
- CAM.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    CAM unit
- Counter.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Counter unit
- Decoder.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Decoder unit
- Encoder.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Encoder unit
- PriorityEnc
    Coded: Yes, Checked: Yes, Tested: Yes

    Priority Encoder unit
- RingBuff.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Ring Buffer unit
- RingBuffCTRL.sv
    Coded: Yes, Checked: Yes, Tested: Yes

    Ring Buffer Controller
