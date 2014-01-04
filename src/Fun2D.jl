
export Fun2D




## Fun2D


type Fun2D{T<:AbstractFun,M<:AbstractFun}
  A::Vector{T}
  B::Vector{M}
  
  function Fun2D(A::Vector{T},B::Vector{M})
    @assert length(A) == length(B)
    new(A,B)
  end
end

Fun2D{T<:AbstractFun,M<:AbstractFun}(A::Vector{T},B::Vector{M})=Fun2D{T,M}(A,B)



findapproxmax(f::Function,dx::Domain,dy::Domain)=findapproxmax(f,dx,dy, 20, 20)
function findapproxmax(f::Function,dx::Domain,dy::Domain, gridx::Integer, gridy::Integer)
    ptsx=points(dx,gridx)
    ptsy=points(dy,gridy)

  mpt=[fromcanonical(dx,rand()),fromcanonical(dy,rand())]  
  maxi=abs(f(mpt[1],mpt[2]))


    for k = 1:length(ptsx),j=1:length(ptsy)
      val=abs(f(ptsx[k],ptsy[j])) 
      if val > maxi
        maxi = val
        mpt[1]=ptsx[k];mpt[2]=ptsy[j]
      end
    end
    mpt
end


Fun2D(f::Function,dx::Domain,dy::Domain)=Fun2D(f,dx,dy,20,20)
function Fun2D(f::Function,dx::Domain,dy::Domain,gridx::Integer,gridy::Integer)
    tol=1000eps()
    
    r=findapproxmax(f,dx,dy,gridx,gridy)
    a=Fun(x->f(x,r[2]),dx)
    b=Fun(y->f(r[1],y),dy)
    A=typeof(a)[];B=typeof(b)[];
    
    
    for k=1:50
        if norm(a.coefficients) < tol && norm(b.coefficients) < tol
            return Fun2D(A,B)
        end
        
        A=[A,a/sqrt(a[r[1]])];B=[B,b/sqrt(b[r[2]])]    
        r=findapproxmax((x,y)->f(x,y) - evaluate(A,B,x,y),dx,dy,gridx,gridy)
        Ar=map(q->q[r[1]],A)
        Br=map(q->q[r[2]],B)
        a=Fun(x->f(x,r[2]),dx) - A*Br
        b=Fun(y->f(r[1],y),dy)- B*Ar
    end
      
    error("Maximum rank of 50 reached")
end

Fun2D(f::Function,d1::Vector,d2::Vector)=Fun2D(f,Interval(d1),Interval(d2))
Fun2D(f::Function)=Fun2D(f,Interval(),Interval())

domain(f::Fun2D,k::Integer)=k==1? first(f.A).domain : first(f.B).domain





evaluate(f::Fun2D,x::Real,y::Real)=evaluate(f.A,f.B,x,y)
evaluate(f::Fun2D,x::Real,::Colon)=f.B*evaluate(f.A,x)
function evaluate(f::Fun2D,::Colon,y::Real)
    m = maximum(map(length,f.A))
    r=rank(f)
    ret = zeros(m)
    ret_v = unsafe_view(ret)
    
    for k=1:r
        for j=1:length(f.A[k])
            ret_v[j] += f.A[k].coefficients[j]*f.B[k][y]
        end
    end
    
    IFun(ret,first(f.A).domain)
end

Base.getindex(f::Fun2D,x,y)=evaluate(f,x,y)

Base.rank(f::Fun2D)=length(f.A)
Base.sum(g::Fun2D)=dot(map(sum,g.A),map(sum,g.B)) #TODO: not complexconjugate
evaluate{T<:AbstractFun,M<:AbstractFun}(A::Vector{T},B::Vector{M},x,y)=dot(evaluate(A,x),evaluate(B,y)) #TODO: not complexconjugate


Base.sum(g::Fun2D,n::Integer)=(n==1)?g.B*map(sum,g.A):g.A*map(sum,g.B) #TODO: Fun*vec should be Array[IFun]
Base.cumsum(g::Fun2D,n::Integer)=(n==1)?Fun2D(map(cumsum,g.A),copy(g.B)):Fun2D(copy(g.A),map(cumsum,g.B))
integrate(g::Fun2D,n::Integer)=(n==1)?Fun2D(map(integrate,g.A),copy(g.B)):Fun2D(copy(g.A),map(integrate,g.B))

for op = (:*,:.*,:./,:/)
    @eval ($op){T<:IFun}(A::Array{T,1},c::Number)=map(f->($op)(f,c),A)
    @eval ($op)(f::Fun2D,c::Number) = Fun2D(($op)(f.A,c),f.B)
end 

