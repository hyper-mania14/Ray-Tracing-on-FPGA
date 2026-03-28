$iverilog = 'C:\iverilog\bin\iverilog.exe'
$vvp      = 'C:\iverilog\bin\vvp.exe'
$SRC      = '..\src'
$OUT      = '.\sim_out'
$INC      = "-I$SRC"

New-Item -ItemType Directory -Force -Path $OUT | Out-Null

$pass = 0
$fail = 0

function Run-TB($name, $files) {
    Write-Host "`n=== $name ===" -ForegroundColor Cyan
    $compileArgs = @('-g2012', $INC, '-o', "$OUT\$name.out") + $files
    $compileOut = & $iverilog @compileArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  COMPILE FAILED:" -ForegroundColor Red
        $compileOut | ForEach-Object { Write-Host "    $_" }
        $script:fail++
        return
    }
    $simOut = & $vvp "$OUT\$name.out" 2>&1
    $simOut | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  SIM FAILED" -ForegroundColor Red
        $script:fail++
    } else {
        Write-Host "  -> PASS" -ForegroundColor Green
        $script:pass++
    }
}

# ---- Run each testbench ----
Run-TB 'hsl2rgb'             @('hsl2rgb_tb.v')
Run-TB 'sdf_primitives'      @('sdf_primitives_tb.v')
Run-TB 'vector_arith'        @('vector_arith_tb.v')
Run-TB 'fixed_point_arith'   @('fixed_point_arith_tb.v')
Run-TB 'fp_inv_sqrt_folded'  @('fp_inv_sqrt_folded_tb.v', "$SRC\fp_inv_sqrt_folded.v")
Run-TB 'ray_generator_folded' @('ray_generator_folded_tb.v', "$SRC\ray_generator_folded.v", "$SRC\fp_inv_sqrt_folded.v")
Run-TB 'sdf_query'           @('sdf_query_tb.v', "$SRC\sdf_query.v")
Run-TB 'ray_unit'            @('ray_unit_tb.v', "$SRC\ray_unit.v", "$SRC\ray_generator_folded.v", "$SRC\sdf_query.v", "$SRC\fp_inv_sqrt_folded.v")
Run-TB 'ray_marcher'         @('ray_marcher_tb.v', "$SRC\ray_marcher.v", "$SRC\ray_unit.v", "$SRC\ray_generator_folded.v", "$SRC\sdf_query.v", "$SRC\fp_inv_sqrt_folded.v")
Run-TB 'bram_manager'        @('bram_manager_tb.v', "$SRC\bram_manager.v")

Write-Host "`n========================================" -ForegroundColor White
Write-Host "Results: $pass passed, $fail failed" -ForegroundColor $(if ($fail -eq 0) {'Green'} else {'Yellow'})
