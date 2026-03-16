`timescale 1ns/1ps

module ray_generator_tb;

parameter DISPLAY_WIDTH  = 640;
parameter DISPLAY_HEIGHT = 480;
parameter H_BITS = 10;
parameter V_BITS = 10;
parameter FP_BITS = 16;
parameter FP_FRAC = 8;
parameter PIPELINE_LATENCY = 7;

logic clk;
logic rst;

logic valid_in;
logic [H_BITS-1:0] hcount;
logic [V_BITS-1:0] vcount;

logic [FP_BITS-1:0] hcount_fp;
logic [FP_BITS-1:0] vcount_fp;

logic [3*FP_BITS-1:0] cam_forward;

logic valid_out;
logic ready_out;
logic [3*FP_BITS-1:0] ray_direction;

/* DUT */

ray_generator #(
    .DISPLAY_WIDTH(DISPLAY_WIDTH),
    .DISPLAY_HEIGHT(DISPLAY_HEIGHT),
    .H_BITS(H_BITS),
    .V_BITS(V_BITS),
    .FP_BITS(FP_BITS),
    .FP_FRAC(FP_FRAC)
) dut (
    .clk_in(clk),
    .rst_in(rst),
    .valid_in(valid_in),
    .hcount_in(hcount),
    .vcount_in(vcount),
    .hcount_fp_in(hcount_fp),
    .vcount_fp_in(vcount_fp),
    .cam_forward_in(cam_forward),
    .valid_out(valid_out),
    .ready_out(ready_out),
    .ray_direction_out(ray_direction)
);

always #5 clk = ~clk;


function automatic signed [FP_BITS-1:0] to_fp(real v);
    to_fp = $rtoi(v * (1<<FP_FRAC));
endfunction

function automatic real from_fp(signed [FP_BITS-1:0] v);
    from_fp = v / real'(1<<FP_FRAC);
endfunction


function automatic signed [FP_BITS-1:0] ray_x;
input [3*FP_BITS-1:0] r;
ray_x = r[FP_BITS-1:0];
endfunction

function automatic signed [FP_BITS-1:0] ray_y;
input [3*FP_BITS-1:0] r;
ray_y = r[2*FP_BITS-1:FP_BITS];
endfunction

function automatic signed [FP_BITS-1:0] ray_z;
input [3*FP_BITS-1:0] r;
ray_z = r[3*FP_BITS-1:2*FP_BITS];
endfunction


function automatic void compute_expected(
    input int px,
    input int py,
    output real rx,
    output real ry,
    output real rz
);

real nx, ny;

nx = (px - DISPLAY_WIDTH/2.0) / DISPLAY_WIDTH;
ny = (py - DISPLAY_HEIGHT/2.0) / DISPLAY_HEIGHT;

rx = nx;
ry = ny;
rz = 1.0;

/* normalize */

real mag;
mag = $sqrt(rx*rx + ry*ry + rz*rz);

rx /= mag;
ry /= mag;
rz /= mag;

endfunction


typedef struct {
    int h;
    int v;
    real rx;
    real ry;
    real rz;
} ray_transaction;

ray_transaction queue[$];


task send_pixel(int px, int py);

real rx,ry,rz;

compute_expected(px,py,rx,ry,rz);

queue.push_back('{px,py,rx,ry,rz});

@(posedge clk);

valid_in = 1;
hcount = px;
vcount = py;

hcount_fp = to_fp(px);
vcount_fp = to_fp(py);

endtask


task check_output();

if(valid_out) begin

    ray_transaction exp;

    exp = queue.pop_front();

    real ax,ay,az;

    ax = from_fp(ray_x(ray_direction));
    ay = from_fp(ray_y(ray_direction));
    az = from_fp(ray_z(ray_direction));

    real err;

    err = $sqrt(
        (ax-exp.rx)*(ax-exp.rx) +
        (ay-exp.ry)*(ay-exp.ry) +
        (az-exp.rz)*(az-exp.rz)
    );

    if(err > 0.05)
    begin
        $display("ERROR ray mismatch pixel (%0d,%0d)",exp.h,exp.v);
        $display("expected: %f %f %f",exp.rx,exp.ry,exp.rz);
        $display("actual  : %f %f %f",ax,ay,az);
        $fatal;
    end

end

endtask


always @(posedge clk)
    check_output();


//// Random camera generator


task random_camera();

real x,y,z,mag;

x = $urandom_range(-100,100)/100.0;
y = $urandom_range(-100,100)/100.0;
z = $urandom_range(10,100)/100.0;

mag = $sqrt(x*x+y*y+z*z);

x/=mag;
y/=mag;
z/=mag;

cam_forward = {
    to_fp(z),
    to_fp(y),
    to_fp(x)
};

endtask

//// Test scenarios


task test_corners();

send_pixel(0,0);
send_pixel(DISPLAY_WIDTH-1,0);
send_pixel(0,DISPLAY_HEIGHT-1);
send_pixel(DISPLAY_WIDTH-1,DISPLAY_HEIGHT-1);

endtask


task test_center();

send_pixel(DISPLAY_WIDTH/2, DISPLAY_HEIGHT/2);

endtask


task random_pixels();

for(int i=0;i<2000;i++)
begin
    send_pixel(
        $urandom_range(0,DISPLAY_WIDTH-1),
        $urandom_range(0,DISPLAY_HEIGHT-1)
    );
end

endtask


task bubble_test();

for(int i=0;i<200;i++)
begin

    @(posedge clk);

    valid_in = $urandom_range(0,1);

    if(valid_in)
    begin
        send_pixel(
            $urandom_range(0,DISPLAY_WIDTH-1),
            $urandom_range(0,DISPLAY_HEIGHT-1)
        );
    end

end

endtask


task throughput_test();

valid_in = 1;

for(int y=0;y<DISPLAY_HEIGHT;y++)
for(int x=0;x<DISPLAY_WIDTH;x++)
    send_pixel(x,y);

endtask

//// Main


initial begin

clk=0;
rst=1;
valid_in=0;

repeat(10) @(posedge clk);

rst=0;

random_camera();

test_center();

test_corners();

random_pixels();

bubble_test();

throughput_test();

#1000

$display("ALL TESTS PASSED");

$finish;

end

endmodule