using HCubature, StaticArrays
using Test

@testset "simple" begin
      @test hcubature(x -> cos(x[1])*cos(x[2]), [0,0], [1,1])[1] ≈ sin(1)^2 ≈
            @inferred(hcubature(x -> cos(x[1])*cos(x[2]), (0,0), (1,1)))[1] ≈
            @inferred(hcubature(x -> cos(x[1])*cos(x[2]), (0.0f0,0.0f0), (1.0f0,1.0f0)))[1]
      @test @inferred(hcubature(x -> cos(x[1]), (0,), (1,)))[1] ≈ sin(1) ≈
            @inferred(hquadrature(cos, 0, 1))[1]
      @test @inferred(hcubature(x -> cos(x[1]), (0.0f0,), (1.0f0,)))[1] ≈ sin(1.0f0)
      @test @inferred(hcubature(x -> 1.7, SVector{0,Float64}(), SVector{0,Float64}()))[1] == 1.7
      @test @inferred(hcubature(x -> 2, (0,0), (2pi, pi))[1]) ≈ 4pi^2
      @test @inferred(hcubature(x -> 2, (0.0f0,0.0f0), (2.0f0*pi, 1.0f0*pi))[1]) ≈ 4pi^2
      @test_throws DimensionMismatch hcubature(x -> 2, [0,0,0], [2,0])
      for d in 1:5
            @test hcubature(x -> 1, fill(0,d), fill(1,d))[1] ≈ 1 rtol=1e-13
      end
end

@testset "count" begin
      (i, e, count) = hcubature_count(x -> 2, (0,0), (2pi, pi))
      @test i ≈ 4pi^2
      @test count == HCubature.countevals(HCubature.GenzMalik(Val(2)))
end

@testset "print" begin
      # Capture println's in a buffer, ensure one printed line per integrand eval
      let io = IOBuffer()
            (i, e, count) = hcubature_print(io, x -> 2, (0,0), (2pi, pi))
            regex = r"f\((?<x>.+?)\) = (?<y>.+?)"
            io_lines = collect(eachmatch(regex, String(take!(io))))
            @test i ≈ 4pi^2
            @test length(io_lines) == count
      end

      # Test hcubature_print(f, a, b) without io arg specified
      # Suppress output of internal printing to stdout
      f() = hcubature_print(x -> 2, (0,0), (2pi, pi))
      (i, e, count) = redirect_stdout(f, devnull);
      @test i ≈ 4pi^2
      @test count == HCubature.countevals(HCubature.GenzMalik(Val(2)))
end

# function wrapper for counting evaluations
const gcnt = Ref(0)
cnt(f) = x -> begin
      gcnt[] += 1
      f(x)
end

@testset "big3d" begin
      let f(x) = sin(x[1] + 3*sin(2*x[2] + 4*sin(3*x[3])))
            gcnt[] = 0
            @test hcubature(cnt(f), (0,0,0),(3,3,3), rtol=1e-6)[1] ≈ -4.78802790509727 rtol=1e-6
            @test 2_400_000 < gcnt[] < 2_500_000
            gcnt[] = 0
            hcubature(cnt(f), (0,0,0),(3,3,3), maxevals=1000)
            @test gcnt[] < 1070
      end
end

@testset "complex" begin
      @test hcubature(x -> cis(x[1]), (0,), (1,))[1] ≈ (cis(1)-1)/im
      @test hcubature(x -> cis(x[1]+x[2]), (0,-1), (1,2))[1] ≈ -(cis(1)-1)*(cis(2)-cis(-1))
end

@testset "countevals" begin
      let g = HCubature.GaussKronrod(Float64)
            @test HCubature.countevals(g) == 2length(g.w) - 1
            gcnt[] = 0
            hquadrature(cnt(one), 0, 1)
            @test HCubature.countevals(g) == gcnt[]
      end
      for n = 2:10
            let g = HCubature.GenzMalik(Val{n}(), Float64)
                  @test HCubature.countevals(g) == 1 + 4length(g.p[1]) + length(g.p[3]) + length(g.p[4])
                  gcnt[] = 0
                  hcubature(cnt(x -> 1.0), ntuple(zero, Val{n}()), ntuple(one, Val{n}()))
                  @test HCubature.countevals(g) == gcnt[]
            end
      end
      @test HCubature.countevals(HCubature.Trivial()) == 1
      gcnt[] = 0
      hcubature(cnt(x -> 1.0), SVector{0,Float64}(), SVector{0,Float64}())
      @test HCubature.countevals(HCubature.Trivial()) == gcnt[]
end

@testset "axischoosing" begin
    #Issue #4
    let f = x -> 1.0 + (x[1] * x[3] * sin(x[2]))^2
        @test hcubature(f, (0.0,0.0,-0.2), (0.2,2π,0.2), rtol=1e-6)[1] ≈ (22502//140625)*π rtol=1e-6
    end
end

@testset "initdiv" begin
      for initdiv = 1:5
            @test sin(1)^2 ≈ hcubature(x -> cos(x[1])*cos(x[2]), [0,0], [1,1], initdiv=initdiv)[1]
            @test sin(1) ≈ @inferred(hquadrature(cos, 0, 1, initdiv=initdiv))[1]
      end
end

@testset "NaN and Inf" begin
      @test hcubature(x -> x[2] < 0 ? NaN : x[1]*x[2], [-1, -1], [1, 1]) === (NaN, NaN)
      @test hcubature(x -> x[2] < 0 ? Inf : x[1]*x[2], [-1, -1], [1, 1]) === (Inf, NaN)
end

@testset "hcubature_buffer" begin
    # 1d
    f = x->cos(x[1])
    a,b = (0,), (1,)
    buffer = hcubature_buffer(f,a,b)
    @test @inferred(hcubature(f,a,b;buffer=buffer))[1] ≈ sin(1) ≈
    @inferred(hquadrature(f, 0, 1; buffer=buffer))[1]
    # 2d
    f = x -> cos(x[1])*cos(x[2])
    a,b = [0,0], [1,1]
    buffer = hcubature_buffer(f,a,b)
    @test hcubature(f,a,b; buffer=buffer)[1] ≈ sin(1)^2 ≈
    @inferred(hcubature(f, Tuple(a), Tuple(b);buffer=buffer))[1]
    # 1d single precision
    f = x -> cos(x[1])
    a,b = (0.0f0,), (1.0f0,)
    buffer = hcubature_buffer(f,a,b)
    @test @inferred(hcubature(f,a,b;buffer=buffer))[1] ≈ sin(1.0f0)
    # 2d complex entries
    f = x -> (1+im)*cos(x[1])*cos(x[2])
    a,b = (0,0), (1, 1)
    buffer = hcubature_buffer(f,a,b)
    @test @inferred(hcubature(f,a,b;buffer=buffer))[1] ≈ (1+im)*sin(1)^2
end

@testset "issue 23" begin
    @test hquadrature(x -> 1.0, 1, -1)[1] ≈ -2
    @test hcubature(x -> 1.0, [-1,1], [1,-1])[1] ≈ -4
end

@testset "issue 60" begin
    T = BigFloat
    @test hquadrature(x -> exp(-x^2), T(0), T(1); rtol = 1e-20)[1] ≈ 0.7468241328124270254
    @test hcubature(x -> exp(-x[1]^2), T.((0,0)), T.((1,1)); rtol = 1e-20)[1] ≈ 0.7468241328124270254
end

# wrappers to test hcubature_print API without printing anything
hcubature_printnull(args...; kws...) = hcubature_print(devnull, args...; kws...)

hcubature_return_evalbuf_printnull(args...; kws...) = hcubature_return_evalbuf_print(devnull, args...; kws...)

@testset "eval_buffer" begin
  osc(x) = sin(33*prod(x) + 5cos(20*sum(x))) # a highly oscillatory function
  I, E, buf, count = hcubature_return_evalbuf_count(osc, [0.0,0.0], [1.0,1.0])
  _I, _E, _count = hcubature_count(osc, [0.0,0.0], [1.0,1.0])
  @test I == _I
  @test E == _E
  @test count == _count

  for q in (hcubature, hcubature_count, hcubature_printnull, hcubature_return_evalbuf, hcubature_return_evalbuf_count, hcubature_return_evalbuf_printnull)
    @test I ≈ q(osc, [0.0,0.0], [1.0,1.0], eval_buffer=buf, maxevals=0)[1] rtol=1e-15
  end

  I2, E2, buf2 = hcubature_return_evalbuf(x -> sin(x[1] + x[2]), [0.0,0.0], [1.0,1.0], maxevals=0) # 1-interval segbuf
  @test buf2.valtree == [HCubature.Box(SVector((0.0,0.0)), SVector(1.0,1.0), I2, E2, only(buf2.valtree).kdiv)]

  hcubature(osc, [0.0,0.0], [1.0,1.0], buffer=buf2)
  @test buf.valtree == buf2.valtree

  hcubature(x -> sin(x[1] + x[2]), [0.0,0.0], [1.0,1.0], buffer=buf2, maxevals=0)
  @test buf2.valtree == [HCubature.Box(SVector((0.0,0.0)), SVector(1.0,1.0), I2, E2, only(buf2.valtree).kdiv)]

  I3, E3, count3 =  hcubature_count(osc, [0.0,0.0], [1.0,1.0], buffer=buf2, eval_buffer=buf, maxevals=0)
  @test buf2.valtree == buf.valtree && buf2 !== buf
  @test I ≈ I3 rtol=1e-15
  @test E ≈ E3 rtol=1e-15
  @test count3 == length(buf)*17

  # the partition should already meet the stopping criteria
  @test hcubature_count(osc, [0.0,0.0], [1.0,1.0], eval_buffer=buf)[3] == length(buf)*17

  # reusing for vector valued integral 
  @test I ≈ hcubature_count(x -> [sin(100*sum(x)), osc(x)], [0.0,0.0], [1.0,1.0], eval_buffer=buf, maxevals=0)[1][2] rtol=1e-15
end
