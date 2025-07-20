/*  =====================================================================
    SHA‑512 & HMAC‑SHA‑512  —  Power Query (M) implementation
    ─────────────────────────────────────────────────────────────────────
    Author : René Reineke rene@o9.digital
    License: MIT  (see LICENSE)
    Repo   : https://github.com/rene-re/SHA512‑M
    Exports:
        • HMAC512(secret as text, msg as text) → text   (RFC 2104, hex)
        • SHA512 (bin as binary)               → binary (64‑byte hash)
        • SelfTest()                           → record (RFC vectors)
    Notes :
        • 100 % managed M — no JavaScript bridge (deprecated in PQ) or
          external DLLs required; works in Excel, Power BI, Dataflows.
    ===================================================================== */

let
//------------------------------------------------------------------
//  1 – 32‑bit helpers
//------------------------------------------------------------------
    UInt32 = (n as number) => let m = Number.Mod(n, 4294967296)
                              in  if m < 0 then m + 4294967296 else m,

    Add32  = (a as number, b as number) => UInt32(a + b),
    Xor32  = Number.BitwiseXor,
    And32  = Number.BitwiseAnd,
    Or32   = Number.BitwiseOr,
    Not32  = Number.BitwiseNot,

    /* logical right‑shift for 32‑bit unsigned words */
    Lsr32 = (v as number, n as number) =>
        Number.IntegerDivide(UInt32(v), Number.Power(2, n)),

    Ror32 = (v as number, n as number) as number =>
        UInt32(
            Or32(
                Lsr32(v, n),                                /* shifted part      */
                Number.BitwiseShiftLeft(
                    Number.Mod(v, Number.Power(2, n)),      /* wrapped‑around    */
                    32 - n)
            )
        ),

//------------------------------------------------------------------
//  2 – 64‑bit helpers
//------------------------------------------------------------------
    Add64 = (p as list, q as list) as list =>
        let lo = Add32(p{1}, q{1}),
            hi = Add32(p{0}, q{0} + (if lo < p{1} then 1 else 0))
        in  { hi, lo },

    Ror64 = (v as list, n as number) as list =>
        let
            hi = UInt32(v{0}),
            lo = UInt32(v{1}),
            shift = Number.Mod(n, 64),

            // Convert number to 32-bit binary string
            ToBin32 = (x as number) =>
                Text.PadStart(
                    Text.Combine(
                        List.Transform(
                            List.Reverse(
                                List.Transform({0..31}, (i) =>
                                    Text.From(Number.Mod(Number.BitwiseShiftRight(x, i), 2))
                                )
                            ),
                            each _
                        )
                    ),
                    32, "0"
                ),

            binHi = ToBin32(hi),
            binLo = ToBin32(lo),
            full64 = binHi & binLo,

            rotated = Text.End(full64, shift) & Text.Start(full64, 64 - shift),
            newHiBits = Text.Start(rotated, 32),
            newLoBits = Text.End(rotated, 32),

            BinToInt = (bin as text) =>
                List.Accumulate(Text.ToList(bin), 0,
                    (state, digit) => state * 2 + (if digit = "1" then 1 else 0)),

            newHi = UInt32(BinToInt(newHiBits)),
            newLo = UInt32(BinToInt(newLoBits))
        in
            { newHi, newLo },

    ShR64 = (p as list, n as number) as list =>
        if   n = 0  then p
        else if n < 32 then
            let hi = p{0}, lo = p{1},
                hi2lo = Number.Mod(UInt32(hi), Number.Power(2,n))
            in {
                Lsr32(hi,n),
                UInt32( Or32( Lsr32(lo,n), Number.BitwiseShiftLeft(hi2lo,32-n) ))
            }
        else if n = 32 then { 0, UInt32(p{0}) }
        else                    { 0, Lsr32(p{0}, n-32) },

    Xor64   = (p as list, q as list) as list => { Xor32(p{0},q{0}), Xor32(p{1},q{1}) },

    sigma0_64 = (x as list) => Xor64(Xor64(Ror64(x, 1), Ror64(x, 8)),  ShR64(x, 7)),
    sigma1_64 = (x as list) => Xor64(Xor64(Ror64(x,19), Ror64(x,61)), ShR64(x, 6)),

    Sigma0_64 = (x as list) => Xor64(Xor64(Ror64(x,28), Ror64(x,34)), Ror64(x,39)),
    Sigma1_64 = (x as list) => Xor64(Xor64(Ror64(x,14), Ror64(x,18)), Ror64(x,41)),

//------------------------------------------------------------------
//  3--  SHA‑512 constants (80 × 64‑bit)
//------------------------------------------------------------------
    K = {
        {0x428a2f98,0xd728ae22},{0x71374491,0x23ef65cd},{0xb5c0fbcf,0xec4d3b2f},{0xe9b5dba5,0x8189dbbc},
        {0x3956c25b,0xf348b538},{0x59f111f1,0xb605d019},{0x923f82a4,0xaf194f9b},{0xab1c5ed5,0xda6d8118},
        {0xd807aa98,0xa3030242},{0x12835b01,0x45706fbe},{0x243185be,0x4ee4b28c},{0x550c7dc3,0xd5ffb4e2},
        {0x72be5d74,0xf27b896f},{0x80deb1fe,0x3b1696b1},{0x9bdc06a7,0x25c71235},{0xc19bf174,0xcf692694},
        {0xe49b69c1,0x9ef14ad2},{0xefbe4786,0x384f25e3},{0x0fc19dc6,0x8b8cd5b5},{0x240ca1cc,0x77ac9c65},
        {0x2de92c6f,0x592b0275},{0x4a7484aa,0x6ea6e483},{0x5cb0a9dc,0xbd41fbd4},{0x76f988da,0x831153b5},
        {0x983e5152,0xee66dfab},{0xa831c66d,0x2db43210},{0xb00327c8,0x98fb213f},{0xbf597fc7,0xbeef0ee4},
        {0xc6e00bf3,0x3da88fc2},{0xd5a79147,0x930aa725},{0x06ca6351,0xe003826f},{0x14292967,0x0a0e6e70},
        {0x27b70a85,0x46d22ffc},{0x2e1b2138,0x5c26c926},{0x4d2c6dfc,0x5ac42aed},{0x53380d13,0x9d95b3df},
        {0x650a7354,0x8baf63de},{0x766a0abb,0x3c77b2a8},{0x81c2c92e,0x47edaee6},{0x92722c85,0x1482353b},
        {0xa2bfe8a1,0x4cf10364},{0xa81a664b,0xbc423001},{0xc24b8b70,0xd0f89791},{0xc76c51a3,0x0654be30},
        {0xd192e819,0xd6ef5218},{0xd6990624,0x5565a910},{0xf40e3585,0x5771202a},{0x106aa070,0x32bbd1b8},
        {0x19a4c116,0xb8d2d0c8},{0x1e376c08,0x5141ab53},{0x2748774c,0xdf8eeb99},{0x34b0bcb5,0xe19b48a8},
        {0x391c0cb3,0xc5c95a63},{0x4ed8aa4a,0xe3418acb},{0x5b9cca4f,0x7763e373},{0x682e6ff3,0xd6b2b8a3},
        {0x748f82ee,0x5defb2fc},{0x78a5636f,0x43172f60},{0x84c87814,0xa1f0ab72},{0x8cc70208,0x1a6439ec},
        {0x90befffa,0x23631e28},{0xa4506ceb,0xde82bde9},{0xbef9a3f7,0xb2c67915},{0xc67178f2,0xe372532b},
        {0xca273ece,0xea26619c},{0xd186b8c7,0x21c0c207},{0xeada7dd6,0xcde0eb1e},{0xf57d4f7f,0xee6ed178},
        {0x06f067aa,0x72176fba},{0x0a637dc5,0xa2c898a6},{0x113f9804,0xbef90dae},{0x1b710b35,0x131c471b},
        {0x28db77f5,0x23047d84},{0x32caab7b,0x40c72493},{0x3c9ebe0a,0x15c9bebc},{0x431d67c4,0x9c100d4c},
        {0x4cc5d4be,0xcb3e42b6},{0x597f299c,0xfc657e2a},{0x5fcb6fab,0x3ad6faec},{0x6c44198c,0x4a475817}
    },

//------------------------------------------------------------------
//  4 – SHA‑512 core
//------------------------------------------------------------------
    SHA512 = (bin as binary) as binary =>
        let
            /* padding -------------------------------------------------------*/
            lenBits = Binary.Length(bin) * 8,
            msg1    = Binary.Combine({ bin, #binary({0x80}) }),
            padLen  = Number.Mod(112 - Number.Mod(Binary.Length(msg1),128) + 128,128),
            pad     = Binary.FromList(List.Repeat({0}, padLen)),

            lenBin  = Binary.Combine({
                          #binary({0,0,0,0,0,0,0,0}),         /* high 64 bits   */
                          Binary.FromList({
                              Number.Mod(Number.BitwiseShiftRight(lenBits,56),256),
                              Number.Mod(Number.BitwiseShiftRight(lenBits,48),256),
                              Number.Mod(Number.BitwiseShiftRight(lenBits,40),256),
                              Number.Mod(Number.BitwiseShiftRight(lenBits,32),256),
                              Number.Mod(Number.BitwiseShiftRight(lenBits,24),256),
                              Number.Mod(Number.BitwiseShiftRight(lenBits,16),256),
                              Number.Mod(Number.BitwiseShiftRight(lenBits, 8),256),
                              Number.Mod(lenBits,256)
                          })
                      }),

            total   = Binary.Combine({msg1, pad, lenBin}),
            blocks  = List.Transform(List.Split(Binary.ToList(total),128), Binary.FromList),

            /* initial hash ---------------------------------------------------*/
            H0 = {
                {0x6a09e667,0xf3bcc908},{0xbb67ae85,0x84caa73b},
                {0x3c6ef372,0xfe94f82b},{0xa54ff53a,0x5f1d36f1},
                {0x510e527f,0xade682d1},{0x9b05688c,0x2b3e6c1f},
                {0x1f83d9ab,0xfb41bd6b},{0x5be0cd19,0x137e2179}
            },

            /* compressor -----------------------------------------------------*/
            Process = (H as list, blk as binary) as list =>
                let
                    /* (a)  message schedule ----------------------------------*/
                    bytes = Binary.ToList(blk),
                    W0    = List.Transform(List.Split(bytes,8),
                              (b)=> { b{0}*16777216 + b{1}*65536 + b{2}*256 + b{3},
                                      b{4}*16777216 + b{5}*65536 + b{6}*256 + b{7} }),
                    W     = List.Accumulate({16..79}, W0,
                              (w,i)=> w & {
                                  Add64(
                                      Add64(
                                          Add64(sigma1_64(w{i-2}), w{i-7}),
                                          sigma0_64(w{i-15})),
                                      w{i-16})
                              }),

                    /* (b)  80 rounds ----------------------------------------*/
                    Rnd   = List.Accumulate({0..79}, H,
                              (v,i)=>
                                  let
                                      a=v{0}, b=v{1}, c=v{2}, d=v{3},
                                      e=v{4}, f=v{5}, g=v{6}, h=v{7},

                                      ch = { Xor32(And32(e{0},f{0}), And32(Not32(e{0}),g{0})),
                                             Xor32(And32(e{1},f{1}), And32(Not32(e{1}),g{1})) },

                                      temp1 = Add64(Add64(Add64(Add64(h,Sigma1_64(e)), ch), K{i}), W{i}),
                                      temp2 = Add64(Sigma0_64(a),
                                                    { Xor32(Xor32(And32(a{0},b{0}),And32(a{0},c{0})),And32(b{0},c{0})),
                                                      Xor32(Xor32(And32(a{1},b{1}),And32(a{1},c{1})),And32(b{1},c{1})) }),
                                      newA  = Add64(temp1, temp2),
                                      newE  = Add64(d, temp1)
                                  in      { newA, a, b, c, newE, e, f, g }),

                    Hn = List.Transform({0..7}, (j)=> Add64(H{j}, Rnd{j}))
                in
                    Hn,

            Hfinal = List.Accumulate(blocks, H0, Process),

            result = List.Combine(
                       List.Transform(Hfinal,
                         (p)=> { Number.Mod(Number.BitwiseShiftRight(p{0},24),256),
                                 Number.Mod(Number.BitwiseShiftRight(p{0},16),256),
                                 Number.Mod(Number.BitwiseShiftRight(p{0}, 8),256),
                                 Number.Mod(p{0},256),
                                 Number.Mod(Number.BitwiseShiftRight(p{1},24),256),
                                 Number.Mod(Number.BitwiseShiftRight(p{1},16),256),
                                 Number.Mod(Number.BitwiseShiftRight(p{1}, 8),256),
                                 Number.Mod(p{1},256) }))


        in
            Binary.FromList(result),
            ToHex = (bin as binary) as text =>
                Text.Lower(Binary.ToText(bin, BinaryEncoding.Hex)),


//------------------------------------------------------------------
//  5 – HMAC‑SHA‑512  (RFC 2104)
//------------------------------------------------------------------
    HMAC512 = (secret as text, msg as text) as text =>
        let
            block = 128,
            key0  = Text.ToBinary(secret,TextEncoding.Utf8),
            key   = if Binary.Length(key0) > block then SHA512(key0) else key0,
            pad   = Binary.Combine({ key,
                       Binary.FromList(List.Repeat({0}, block-Binary.Length(key))) }),
            ipad  = Binary.FromList(
                       List.Transform(Binary.ToList(pad), each Number.BitwiseXor(_,0x36))),
            opad  = Binary.FromList(
                       List.Transform(Binary.ToList(pad), each Number.BitwiseXor(_,0x5c))),
            inner = SHA512(
                       Binary.Combine({ipad, Text.ToBinary(msg,TextEncoding.Utf8)})),
            outer = SHA512(Binary.Combine({opad,inner}))
        in
            ToHex(outer),


//------------------------------------------------------------------
//  6 – helper for self‑tests
//------------------------------------------------------------------
    BytesToText = (bytes as list) =>
        Text.FromBinary(Binary.FromList(bytes), TextEncoding.Utf8),

//------------------------------------------------------------------
//  7 – extended self‑tests  (RFC 6234 / RFC 4231)
//------------------------------------------------------------------
    SelfTest = () as record =>
        let
            /* SHA‑512 --------------------------------------------------------*/
            expEmpty =
                "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc" &
                "83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f" &
                "63b931bd47417a81a538327af927da3e",
            expABC   =
                "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea2" &
                "0a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd" &
                "454d4423643ce80e2a9ac94fa54ca49f",

            gotEmpty = ToHex(SHA512(#binary({}))),
            gotABC   = ToHex(SHA512(Text.ToBinary("abc",TextEncoding.Utf8))),

            /* HMAC test vectors ---------------------------------------------*/
            k1 = BytesToText(List.Repeat({0x0b},20)),
            m1 = "Hi There",
            expH1 =
                "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec278" &
                "7ad0b30545e17cdedaa833b7d6b8a702038b274eaea3f4e4" &
                "be9d914eeb61f1702e696c203a126854",

            k2 = "Jefe",
            m2 = "what do ya want for nothing?",
            expH2 =
                "164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd6" &
                "10270cd7ea2505549758bf75c05a994a6d034f65f8f0e6fd" &
                "caeab1a34d4a6b4b636e070a38bce737",

            expH11 =
                "9488141233b198df76a47df9dc38d031cc68e99901bd44d4" &
                "61adceaa224698de4f63e5e6f9c01fced53f1fc456eaec83" &
                "6f094215c5e121ab8af3f31ced12dbcc",

            gotH1  = HMAC512(k1, m1),
            gotH2  = HMAC512(k2, m2),
            gotH11 = HMAC512("1","1"),

            tests = [

                SHA512_Empty   = [Expected = expEmpty, Got = gotEmpty,
                                  Ok = (gotEmpty = expEmpty)],
                SHA512_abc     = [Expected = expABC , Got = gotABC ,
                                  Ok = (gotABC = expABC )],
                HMAC_RFC4231_1 = [Expected = expH1  , Got = gotH1  ,
                                  Ok = (gotH1  = expH1 )],
                HMAC_RFC4231_2 = [Expected = expH2  , Got = gotH2  ,
                                  Ok = (gotH2  = expH2 )],
                HMAC11         = [Expected = expH11 , Got = gotH11 ,
                                  Ok = (gotH11 = expH11)]
            ],

            allOk = List.AllTrue(
                        List.Transform(Record.FieldValues(tests), each _[Ok]))
        in
            Record.AddField(tests, "AllPass", allOk)

in
    [
        HMAC512 = HMAC512,
        SHA512  = SHA512,
        SelfTest = SelfTest
    ]