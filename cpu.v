`timescale 1ns/1ps

module main(input [3:0] buttons); //inputs are mapped to by the pin planner in Quartus 2

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0,main);
    end

    //input signals
    wire [3:0] pulse;

    // clock
    wire clk;
    clock c0(clk);

    reg halt = 0;
    wire d_halt;
    reg x_halt = 0;
    reg m_halt = 0;
    reg wb_halt = 0;

    counter ctr(halt,clk);

    // Valid bits
    reg f0_valid = 1;
    reg f1_valid = 0;
    reg ins_valid = 0;
    reg ins_queue0_valid = 0;
    reg d_valid = 0;
    reg x_valid = 0;
    reg m_valid = 0;
    reg wb_valid = 0;

    // PC
    reg [15:1]f_pc = 15'h0;
    wire [15:1]d_pc;
    reg [15:1]f1_pc, ins_pc, ins_queue0_pc, ins_queue1_pc, x_pc, m_pc, wb_pc;

    // Read ports for memory
    wire [15:0]ld_addr;
    wire [15:0]ins;
    wire [7:0]ld_data;

    // Write ports for memory
    wire mem_wen;
    wire [15:0]x_str_addr; reg [15:0]m_str_addr, wb_str_addr;
    wire [7:0]x_str_data; reg [7:0]m_str_data, wb_str_data;

    // memory
    memcontroller mem(clk, f_pc, ins, ld_addr, ld_data, mem_wen, wb_str_addr, wb_str_data);

    // Instruction queue to capture instructions output from memory while decode stalls
    // Position 1 has priority in the queue
    reg ins_queue0_full = 0;
    reg ins_queue1_full = 0;
    reg [15:0]ins_queue0_data, ins_queue1_data;

    // Wire for current instruction to decode
    wire [15:0]d_ins;
    assign d_ins =  ins_queue1_full ? ins_queue1_data :
                    ins_queue0_full ? ins_queue0_data : ins;
    assign d_pc =   ins_queue1_full ? ins_queue1_pc :
                    ins_queue0_full ? ins_queue0_pc : ins_pc;

    // Regs to record whether memory store data has been forwarded
    reg m_str_forwarded, wb_str_forwarded;

    // Instruction opcode signals
    wire [3:0]opcode;
    assign opcode = d_ins[15:12];
    wire d_isimmadd, d_isregadd, d_issub, d_ismovi, d_ismovh, d_isjmp, d_isld, d_isldp, d_isstri, d_isstr, d_isstrp;
    reg x_isimmadd, x_isregadd, x_issub, x_ismovi, x_ismovh, x_isjmp, x_isld, x_isstri, x_isstr;
    reg m_isld = 0; reg m_isstr = 0;
    reg wb_isld = 0; reg wb_isstr = 0;
    reg m_isjmp, wb_isjmp;

    assign d_halt = (opcode == 4'b0000) && d_ins[11];
    assign d_isimmadd = opcode == 4'b0001;
    assign d_isregadd = opcode == 4'b0010;
    assign d_issub = d_ins[11];
    assign d_ismovi = opcode == 4'b0011 && !d_ins[11];
    assign d_ismovh = opcode == 4'b1001;
    assign d_isjmp = opcode == 4'b1110;
    assign d_isldp = opcode == 4'b1111 && d_ins[7:4] == 4'b0010;
    assign d_isld = d_isldp | (opcode == 4'b1111 && d_ins[11:9] == 4'b100 && d_ins[5:3] == 3'b000);
    assign d_isstri = opcode == 4'b1111 && d_ins[11] == 0;
    assign d_isstrp = opcode == 4'b1111 && d_ins[7:4] == 4'b0011;
    assign d_isstr = d_isstri | d_isstrp | (opcode == 4'b1111 && d_ins[11:9] == 4'b100 && d_ins[5:3] == 3'b001);

    // Load/store pair phase counter
    reg pair_phase = 0;
    wire x_is_strp1 = d_valid & d_isstrp & (pair_phase == 1);

    // Memory write enable
    assign mem_wen = wb_valid & wb_isstr;

    // Instruction a,b,t register
    wire [2:0]ra, rb, rt;
    assign ra = d_ins[8:6];
    assign rb = d_ins[5:3];
    assign rt = d_ins[2:0];

    // Instruction immediate
    wire [7:0]d_imm; reg [7:0]x_imm;
    assign d_imm = d_isstri ? {d_ins[10:9], d_ins[5:0]}: d_ins[10:3];

    //wire [15:0]imml, immh;
    //assign imml = {{8{x_imm[7]}}, x_imm};
    //assign immh = {x_imm, 8'b0};

    // Jump type control signals
    wire [3:0]d_jmptype; reg [3:0]x_jmptype;
    assign d_jmptype = d_ins[7:4];

    // Read ports from registers
    wire [2:0]d_regraddr0, d_regraddr1; reg [2:0]x_regraddr0, x_regraddr1;
    wire [7:0]regrdata0, regrdata1;

    assign d_regraddr0 =    d_isimmadd ? rt : ra;
    assign d_regraddr1 =    (d_valid & d_isstrp & (pair_phase == 0)) ? rt + 1 :
                            (d_isimmadd || d_isjmp || d_ismovh || d_isstr) ? rt : rb;

    // Write port from registers
    wire d_regwen; reg x_regwen, m_regwen, wb_regwen;
    wire [2:0]d_regwaddr; reg [2:0]x_regwaddr, m_regwaddr, wb_regwaddr;
    wire [7:0]x_regwdata; reg [7:0]m_regwdata, wb_regwdata;

    wire master_regwen = wb_valid & wb_regwen;
    wire [2:0]master_regwaddr = wb_regwaddr;
    wire [7:0]master_regwdata = (wb_isld & !wb_str_forwarded) ? ld_data : wb_regwdata;

    assign d_regwen = !halt && (d_ismovi || d_ismovh || d_isimmadd || d_isregadd || d_isld);
    assign d_regwaddr = rt;

    // registers
    ioregs regs(
        clk,
        d_regraddr0, regrdata0,
        d_regraddr1, regrdata1,
        master_regwen, master_regwaddr, master_regwdata);

    // Forwarding-aware register read data
    wire [7:0]reg_fw_data0, reg_fw_data1;
    assign reg_fw_data0 =   x_regraddr0 == 0 ?                                          0 :
                            (x_regraddr0 == m_regwaddr) & m_regwen & m_valid ?          m_regwdata :
                            (x_regraddr0 == master_regwaddr) & wb_regwen & wb_valid ?   master_regwdata : regrdata0;
    assign reg_fw_data1 =   x_regraddr1 == 0 ?                                          0 :
                            (x_regraddr1 == m_regwaddr) & m_regwen & m_valid ?          m_regwdata :
                            (x_regraddr1 == master_regwaddr) & wb_regwen & wb_valid ?   master_regwdata : regrdata1;

    // Load and store address
    assign ld_addr = (d_valid & d_isldp & (pair_phase == 1)) ? reg_fw_data0 + 1 : reg_fw_data0;
    //assign x_str_addr = reg_fw_data0[15:1];
    assign x_str_addr = x_is_strp1 ? reg_fw_data0 + 1 : reg_fw_data0;
    // Store data
    assign x_str_data = x_isstri ? x_imm : reg_fw_data1;

    // ALU input/output
    wire [7:0]aluin0, aluin1, aluout;
    wire alusub, alueq, alult;

    assign aluin0 = reg_fw_data0;
    assign aluin1 = x_isimmadd ? x_imm :
                    x_isjmp ? 0 : reg_fw_data1;
    assign alusub = x_issub;

    // ALU
    alu alu(aluin0, aluin1, alusub, , aluout, alueq, alult);

    // Memory forwarding flags for execute stage
    wire forward_m_mem, forward_wb_mem;
    assign forward_m_mem = x_isld & m_valid & m_isstr & (m_str_addr == ld_addr);
    assign forward_wb_mem = x_isld & wb_valid & wb_isstr & (wb_str_addr == ld_addr);

    // Register write data
    assign x_regwdata = x_ismovi ? x_imm :
                        x_ismovh ? {x_imm, reg_fw_data1[7:0]} : 
                        forward_m_mem ? m_str_data :
                        forward_wb_mem ? wb_str_data : aluout;

    // Jump condition
    assign x_jmp_cond = (x_jmptype == 4'b0000) ? alueq :
                        (x_jmptype == 4'b0001) ? !alueq :
                        (x_jmptype == 4'b0010) ? alult :
                        (x_jmptype == 4'b0011) ? !alult : 0;

    // Jump targeting
    wire [15:1]x_jmp_target; reg [15:1]m_jmp_target, wb_jmp_target;
    wire [15:1]f_jmp_prediction, d_jmp_prediction;
    reg [15:1]f1_jmp_prediction, ins_jmp_prediction, ins_queue0_jmp_prediction, ins_queue1_jmp_prediction, x_jmp_prediction;
    wire x_jmp_mispredict; reg m_jmp_mispredict, wb_jmp_mispredict;

    //assign x_jmp_target = x_jmp_cond ? reg_fw_data1[15:1] : x_pc + 1;
    assign x_jmp_target = (x_isjmp & x_jmp_cond) ? reg_fw_data1[15:1] : x_pc + 1;

    //assign f_jmp_prediction = f_pc + 1;
    reg m_jumping, wb_jumping;
    predictor predictor(clk, f_pc, f_jmp_prediction, wb_jumping & wb_valid, wb_pc, wb_jmp_target, wb_jmp_mispredict & wb_valid, wb_isjmp & wb_valid);
    assign d_jmp_prediction =   ins_queue1_full ? ins_queue1_jmp_prediction :
                                ins_queue0_full ? ins_queue0_jmp_prediction : ins_jmp_prediction;

    reg strp_mispredict = 0;
    //assign x_jmp_mispredict =   (x_isjmp & (x_jmp_target != x_jmp_prediction));
    assign x_jmp_mispredict =   (x_isjmp & (x_jmp_target != x_jmp_prediction)) |
                                ((x_isstr & !x_is_strp1) & ((x_pc + 5 > x_str_addr[15:1]) & (x_str_addr[15:1] > x_pc))) |
                                strp_mispredict;

    // Flush signal
    wire flush;
    //assign flush = 0;
    assign flush = wb_valid & wb_jmp_mispredict;

    // Instruction type validation
    reg halt_found = 0;
    wire illegal_ins;
    //assign illegal_ins = d_valid & (({d_halt, d_isregadd, d_ismovi, d_ismovh, d_isjmp, d_isld, d_isstr} == 7'b0) | (d_isjmp & (d_jmptype > 3)) | d_ins === 16'bx);
    assign illegal_ins = d_valid & (({d_halt, d_isimmadd, d_isregadd, d_ismovi, d_ismovh, d_isjmp, d_isld, d_isstr} == 8'b0) | (d_isjmp & (d_jmptype > 3)));

    // Stalling
    wire f_stall, d_stall, x_stall, m_stall;

    assign f_stall = d_stall;
    assign d_stall =    x_stall |
                        (d_valid & (d_isldp | d_isstrp) & (pair_phase == 0)) |
                        (x_valid & x_isld & ((x_regwaddr == d_regraddr0) | (x_regwaddr == d_regraddr1)));
    assign x_stall = m_stall;

    reg stall_default = 0;
    assign m_stall = stall_default;

    always @(posedge clk) begin
        /*if (f_pc == 20) begin
            x_halt <= 1;
        end*/
        /*if(d_ins === 16'bx) begin
            halt <= 1;
        end*/
        /*if(d_isregadd) begin
            $write("a: %d, b: %d, t: %d\n", ra, rb, rt);
            $write("ra: %d, rb: %d, rt: %d\n", regrdata0, regrdata1, x_regwdata);
            $write("rt(c): %c\n\n", x_regwdata);
            //$write("a: %d, b: %d, t: %d\n", regrdata0, d_isregadd ? ~regrdata1 : regrdata1, x_regwdata);
            //$write("out: %d\n\n", aluout);
        end*/
        //$write("aout = %x or %c\n", aluout, aluout);
        //$write("opcode = %x\n", opcode);
        //$write("data = %x\n", x_jmp_cond);
        /*if(isjmp) begin
            $write("jmpcode: %x\n", jmptype);
            $write("addr: %d\n", d_regraddr0);
            $write("data: %d\n", regrdata0);
            $write("target addr: %d\n", d_regraddr1);
            $write("target: %x\n\n", regrdata1);
        end*/
        /*if(ismovh) begin
            $write("imm: %x\n", immh);
            $write("data: %x\n", x_regwdata);
            //$write("in0: %x\n", aluin0);
            //$write("in1: %x\n", aluin1);
            $write("\n");
        end*/
        /*if(ismovl) begin
            $write("t: %d\n", rt);
            $write("imm: %x\n", imml);
            //$write("immc: %c\n", imml);
            $write("\n");
        end*/
        /*$write("f pc = %x, f stall: %x\n", f_pc, f_stall);
        //$write("alu: %x + %x = %x\n", aluin0, aluin1, aluout);
        //$write("raddr0 = %x, raddr1 = %x\n", d_regraddr0, d_regraddr1);
        //$write("cond: %x\n", d_isld);
        $write("i = %x, 0 = %x, 1 = %x, d ins = %x\n", ins, ins_queue0_data, ins_queue1_data, d_ins);
        $write("0 full: %x, 1 full: %x\n", ins_queue0_full, ins_queue1_full);
        //$write("ins v: %x\n", ins_valid);
        //$write("d valid = %x, d stall = %x, d halt = %x\n", d_valid, d_stall, d_halt);
        //$write("x str_addr = %x\n", x_str_addr);
        //$write("x str_addr2 = %x\n", reg_fw_data0);
        //$write("x str_data = %x\n", x_str_data);
        //$write("pair phase = %x\n", pair_phase);
        //$write("x ld = %x\n", x_isld);
        //$write("fw0: %x, fw1: %x\n", reg_fw_data0, reg_fw_data1);
        //$write("x regrdata1: %x\n", regrdata1);
        $write("x write: (%x, %x, %x), valid = %x, h:%x\n", x_regwen & x_valid, x_regwaddr, x_regwdata, x_valid, x_halt);
        //$write("x valid = %x, x stall = %x\n", x_valid, x_stall);
        $write("x jmp miss: %x, target: %x\n", x_jmp_mispredict, x_jmp_target);
        $write("m write: (%x, %x, %x), valid = %x, h:%x\n", m_regwen & m_valid, m_regwaddr, m_regwdata, m_valid, m_halt);
        $write("m jmp miss: %x, target: %x\n", m_jmp_mispredict, m_jmp_target);
        $write("wb write: (%x, %x, %x), valid = %x, h:%x\n", (wb_regwen & wb_valid), wb_regwaddr, wb_regwdata, wb_valid, wb_halt);
        $write("wb jmp miss: %x, target: %x, flush: %x\n", wb_jmp_mispredict, wb_jmp_target, flush);
        $write("master write: (%x, %x, %x)\n", master_regwen, master_regwaddr, master_regwdata);
        //$write("mem write: (%x, %x, %x)\n", mem_wen, wb_str_addr, wb_str_data);
        $write("\n");*/

        f0_valid <= 1;
        // Fetch
        /*if (!f_stall) begin
            f_pc <= flush ? wb_jmp_target : f_jmp_prediction;
        end*/
        f_pc <= flush ? wb_jmp_target :
                !f_stall ? f_jmp_prediction : f_pc;
        f1_pc <= f_pc;
        ins_pc <= f1_pc;
        f1_jmp_prediction <= f_jmp_prediction;
        ins_jmp_prediction <= f1_jmp_prediction;

        f1_valid <= f0_valid & !f_stall & !flush;
        ins_valid <= f1_valid & !flush;
        ins_queue0_valid <= !flush & ((d_stall & ins_queue1_full) ? ins_queue0_valid : ins_valid);
        d_valid <= (f1_valid | ins_queue0_full) & !flush & !(d_valid && d_halt) & !halt_found;

        // Manage instruction queue for decode
        ins_queue0_data <= (d_stall & ins_queue1_full) ? ins_queue0_data : ins;
        ins_queue1_data <= (d_stall & ins_queue1_full) ? ins_queue1_data : ins_queue0_data;
        ins_queue0_full <=  flush ? 0 :
                            d_stall ? 1 :
                            (!ins_queue1_full & ins_queue0_full) ? ins_valid :
                            ins_queue1_full ? (ins_queue0_valid | ins_valid) : 0;
        ins_queue1_full <=  flush ? 0 :
                            d_stall ? ins_queue0_full :
                            ins_queue1_full ? ins_queue0_valid : 0;
        ins_queue0_pc <= (d_stall & ins_queue1_full) ? ins_queue0_pc : ins_pc;
        ins_queue1_pc <= (d_stall & ins_queue1_full) ? ins_queue1_pc : ins_queue0_pc;
        ins_queue0_jmp_prediction <= (d_stall & ins_queue1_full) ? ins_queue0_jmp_prediction : ins_jmp_prediction;
        ins_queue1_jmp_prediction <= (d_stall & ins_queue1_full) ? ins_queue1_jmp_prediction : ins_queue0_jmp_prediction;

        // Decode
        if (!d_stall | (d_valid & (d_isldp | d_isstrp) & (pair_phase == 0))) begin
            x_pc <= d_pc;
            x_jmp_prediction <= d_jmp_prediction;
            {x_regraddr0, x_regraddr1} <= {d_regraddr0, d_regraddr1};
            x_regwen <= d_regwen;
            x_regwaddr <= (d_valid & d_isldp & (pair_phase == 0)) ? d_regwaddr + 1: d_regwaddr;
            x_imm <= d_imm;
            x_jmptype <= d_jmptype;
            {x_halt, x_isimmadd, x_isregadd, x_issub, x_ismovi, x_ismovh, x_isjmp, x_isld, x_isstri, x_isstr} <=
            {d_halt, d_isimmadd, d_isregadd, d_issub, d_ismovi, d_ismovh, d_isjmp, d_isld, d_isstri, d_isstr};
        end
        halt_found <= !flush & ((d_halt && d_valid) | halt_found);
        //pair_phase <= (d_valid & (d_isldp | d_isstrp)) ? !pair_phase : 0;
        pair_phase <=   !(d_valid & (d_isldp | d_isstrp)) ? 0 :
                        (x_valid & (x_pc == d_pc)) ? 0 : 1;
        x_valid <=  d_valid & !flush & !illegal_ins &
                    ((d_stall & x_stall) | (!d_stall & !x_stall) | ((d_isldp | d_isstrp) & (pair_phase == 0)));

        // Execute
        if (!x_stall) begin
            m_pc <= x_pc;
            m_valid <= x_valid;
            m_halt <= x_halt & x_valid;
            {m_regwen, m_regwaddr, m_regwdata} <= {x_regwen, x_regwaddr, x_regwdata};
            {m_str_addr, m_str_data} <= {x_str_addr, x_str_data};
            m_isld <= x_isld;
            m_isstr <= x_isstr;
            m_str_forwarded <= forward_m_mem | forward_wb_mem;
            m_jumping <= x_jmp_cond & x_isjmp;
            m_jmp_target <= x_jmp_target;
            strp_mispredict <= x_is_strp1 & ((x_pc + 5 > x_str_addr[15:1]) & (x_str_addr[15:1] > x_pc));
            m_jmp_mispredict <= x_jmp_mispredict;
            m_isjmp <= x_isjmp;
        end
        m_valid <= x_valid & !flush & ((x_stall & m_stall) | (!x_stall & !m_stall));

        // Memory
        if (!m_stall) begin
            wb_pc <= m_pc;
            //halt <= (m_halt & m_valid & !flush) | f_pc == 180;
            {wb_regwen, wb_regwaddr, wb_regwdata} <= {m_regwen, m_regwaddr, m_regwdata};
            {wb_str_addr, wb_str_data} <= {m_str_addr, m_str_data};
            wb_isld <= m_isld;
            wb_isstr <= m_isstr;
            wb_str_forwarded <= m_str_forwarded;
            wb_jumping <= m_jumping;
            wb_jmp_target <= m_jmp_target;
            wb_jmp_mispredict <= m_jmp_mispredict;
            wb_isjmp <= m_isjmp;
        end
        halt <= (!m_stall & m_halt & m_valid & !flush);
        wb_valid <= m_valid & !flush;
    end
endmodule
