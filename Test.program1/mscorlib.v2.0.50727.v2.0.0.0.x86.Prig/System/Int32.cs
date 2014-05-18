﻿
using Urasandesu.Prig.Framework;

namespace System.Prig
{
    public class PInt32 : PInt32Base
    {
        public static class TryParse
        {
            public static IndirectionOutFunc<System.String, System.Int32, System.Boolean> Body
            {
                set
                {
                    var info = new IndirectionInfo();
                    info.AssemblyName = "mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089";
                    info.Token = TokenOfTryParse_string_intRef;
                    var holder = LooseCrossDomainAccessor.GetOrRegister<IndirectionHolder<IndirectionOutFunc<System.String, System.Int32, System.Boolean>>>();
                    holder.AddOrUpdate(info, value);
                }
            }
        }
    }
}
