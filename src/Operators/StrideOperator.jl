

export StrideOperator,StrideRowOperator



#S[rowstride*k + rowindex,colstride*j + colindex] == op[k,j]
#S[k,j] == op[(k-rowindex)/rowstride,(j-colindex)/colstride]
type StrideOperator{T<:Number,B<:Operator{T}} <: BandedOperator{T}
    op::B
    rowindex::Int       
    colindex::Int       
    rowstride::Int
    colstride::Int
    
    function StrideOperator(o,r,c,rs,cs)
        @assert abs(rs) == abs(cs)
        @assert rs != 0
        
        new(o,r,c,rs,cs)
    end
end

StrideOperator{T<:Number}(B::Operator{T},r,c,rs,cs)=StrideOperator{T,typeof(B)}(B,r,c,rs,cs)
StrideOperator{T<:Number}(B::Operator{T},r,c,rs)=StrideOperator{T,typeof(B)}(B,r,c,rs,rs)

function bandrange(S::StrideOperator)
    br=bandrange(S.op)
    
    st = abs(S.colstride)
    
    if S.colstride > 0 && S.rowstride > 0
        min(st*br[1]-S.rowindex+S.colindex,0):max(st*br[end]-S.rowindex+S.colindex,0)
    elseif S.colstride > 0
        min(-(S.colindex+S.rowindex-2+st*br[end]),0):max(S.colindex+S.rowindex-2+st*br[end],0)
    elseif S.rowstride > 0
        min(-(S.colindex+S.rowindex-2-st*br[1]),0):max(S.colindex+S.rowindex-2-st*br[1],0)
    else
        min(-st*br[end]-S.rowindex+S.colindex,0):max(-st*br[1]-S.rowindex+S.colindex,0)
    end
end

# First index above
function firstrw(S,k::Integer)
    rs = S.rowstride
    ri= S.rowindex
    rs>0?fld(k-ri+rs-1,rs):fld(k-ri,rs)
end
#Last index below
function lastrw(S,k::Integer)
    rs = S.rowstride
    ri= S.rowindex
    rs>0?fld(k-ri,rs):fld(k-ri+rs+1,rs)
end


function divrowrange(S,r)
    if S.rowstride > 0
        firstrw(S,r[1]):lastrw(S,r[end])
    else #neg neg
        lastrw(S,r[end]):firstrw(S,r[1])
    end
end



#S[rowstride*k + rowindex,colstride*j + colindex] == op[k,j]
#S[k,j] == A[k,j-k]
#A[rowstride*k + rowindex,colstride*j + colindex - k] == op[k,j]

function stride_pospos_addentries!(S::StrideOperator,A::ShiftArray,kr::Range1)
    r1=divrowrange(S,kr)

    B1=BandedArray(S.op,r1)
    B=BandedArray(A)
    
    for k=r1, j=columnrange(B1.data)+k
        B[S.rowstride*k + S.rowindex,S.colstride*j + S.colindex] = B1.data[k,j-k]
    end
    
    A
end

function stride_posneg_addentries!(S::StrideOperator,A::ShiftArray,kr::Range1)
    r1=divrowrange(S,kr)
    B1=ShiftArray(S.op,r1)
    B=BandedArray(A)
    
    for k=r1, j=bandrange(S.op)
        if S.colstride*(j+k) + S.colindex > 0 && S.rowstride*k + S.rowindex > 0
            B[S.rowstride*k + S.rowindex,S.colstride*(j+k) + S.colindex] = B1[k,j]
        end
    end

    
    A
end

function addentries!(S::StrideOperator,A,kr)
    if S.rowstride > 0 && S.colstride > 0
        stride_pospos_addentries!(S,A,kr)
    elseif S.rowstride > 0
        stride_posneg_addentries!(S,A,kr)    
    elseif S.colstride > 0
        stride_posneg_addentries!(S,A,kr)            
    else #neg neg
        stride_pospos_addentries!(S,A,kr)            
    end
end


domain(S::StrideOperator)=Any ##TODO: tensor product


## StrideRowOperator


type StrideRowOperator{T<:Number,B<:RowOperator} <: RowOperator{T}
    op::B
    rowindex::Int
    stride::Int  
end

StrideRowOperator{T<:Number}(B::RowOperator{T},r,rs)=StrideRowOperator{T,typeof(B)}(B,r,rs)


Base.getindex{T<:Number}(op::StrideRowOperator{T},kr::Range1)=[((k-op.rowindex)%op.stride==0)?op.op[fld(k-op.rowindex,op.stride)]:zero(T) for k=kr]



##interlace block operators

iszerooperator(A::ConstantOperator)=A.c==0.
iszerooperator(A)=false
function isboundaryrow(A,k)
    for j=1:size(A,2)
        if typeof(A[k,j]) <: RowOperator
            return true
        end
    end
        
    return false
end

function interlace{T<:Operator}(A::Array{T,2})
    m,n=size(A)

    br=m-n #num boundary rows

    for k=1:br
        @assert isboundaryrow(A,k) 
    end
    
    S=Array(Operator,br+1)
    
    for k=1:br, j=1:n
        if !iszerooperator(A[k,j])
            op = StrideRowOperator(A[k,j],j-n,n)
            
            if !isdefined(S,k)
                S[k] = op
            else
                S[k] = S[k] + op
            end
        end
    end

    for k=br+1:m
        Ap=promotespaces([A[k,:]...])
        
        for j=1:n
            if !iszerooperator(A[k,j])  #not sure what promote does for constant operator
                op = StrideOperator(Ap[j],k-br-n,j-n,n)
            
                if !isdefined(S,br+1)
                    S[br+1] = op
                else
                    S[br+1] = S[br+1] + op
                end
            end            
        end
    end
    
    if(size(S,1) ==1)
        S[1]
    else
        S
    end
end

## only works for BandedShiftOperator
function interlace(L::Operator)
    SPP=StrideOperator(L,1,1,2,2)
    SMM=StrideOperator(L,0,0,-2,-2)
    SPM=StrideOperator(L,0,1,-2,2)
    SMP=StrideOperator(L,1,0,2,-2)
    
    SPM+SMP+SPP+SMM
end


