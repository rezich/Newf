// credit: onelivesleft

#import "Basic";

winsock :: #system_library "ws2_32";

WSADESCRIPTION_LEN :: 256;
WSASYS_STATUS_LEN  :: 128;

WSAData :: struct {
    wVersion     : u16;
    wHighVersion : u16;
    iMaxSockets  : u16;
    iMaxUdpDg    : u16;
    lpVendorInfo : *u8;
    szDescription  : [WSADESCRIPTION_LEN+1] u8;
    szSystemStatus : [WSASYS_STATUS_LEN+1] u8;
}

in_addr :: struct {
    union {
        s_un_b : struct {
            s_b1 : u8;
            s_b2 : u8;
            s_b3 : u8;
            s_b4 : u8;
        };
        s_un_w : struct {
            s_w1 : u16;
            s_w2 : u16;
        };
        s_addr : u32;
    }
}

sockaddr :: struct {
    sa_family : u16;
    sa_data   : [14] u8;
}

sockaddr_in :: struct {
    sin_family: s16;
    sin_port :  u16;
    sin_addr :  in_addr;
    sin_zero :  [8] u8;
}

FD_SETSIZE :: 64;
fd_set :: struct {
    fd_count: u32;
    fd_array: [FD_SETSIZE] Socket;
}

WSAStartup :: (version: u16, wsaData: *WSAData) -> u32 #foreign winsock;
WSACleanup :: () -> s32 #foreign winsock;
WSAGetLastError :: () -> s32 #foreign winsock;

accept :: (s: Socket, addr: *sockaddr, addrlen: *int) -> Socket #foreign winsock;
bind :: (s: Socket, address: *sockaddr, namelen: int) -> s32 #foreign winsock;
closesocket :: (s: Socket) -> s32 #foreign winsock;
htonl :: (hostlong: u32) -> u32 #foreign winsock;
htons :: (hostshort: u16) -> u16 #foreign winsock;
ioctlsocket :: (s: Socket, cmd: s32, argp: *u32) -> int #foreign winsock;
listen :: (s: Socket, backlog: int) -> s32 #foreign winsock;
recv :: (s: Socket, data: *u8, length: s32, flags: u32) -> s32 #foreign winsock;
send :: (s: Socket, buf: *u8, len: s32, flags: s32) -> s32 #foreign winsock;
shutdown :: (s: Socket, how: s32) -> s32 #foreign winsock;
socket :: (af: s32, type: s32, protocol: s32) -> Socket #foreign winsock;

MAKEWORD :: inline (low: u8, high: u8) -> u16 { return cast(u16)((high << 8) | low); }

WINSOCK_VERSION :: #run MAKEWORD(2, 2);

IOCPARM_MASK :: 0x7f;
IOC_IN :: 0x80000000;
/*_IOW :: (x,y,t) => (IOC_IN|((cast(s32)size_of(type_of(t))&IOCPARM_MASK)<<16)|((x)<<8)|(y));
FIONBIO :: #run _IOW(#char "f", 126, u32);*/
FIONBIO :: -2147195266;
#assert(FIONBIO == -2147195266);

AF_UNSPEC    ::  0;
AF_INET      ::  2;
AF_IPX       ::  6;
AF_APPLETALK :: 16;
AF_NETBIOS   :: 17;
AF_INET6     :: 23;
AF_IRDA      :: 26;
AF_BTH       :: 32;

SOCK_STREAM    :: 1;
SOCK_DGRAM     :: 2;
SOCK_RAW       :: 3;
SOCK_RDM       :: 4;
SOCK_SEQPACKET :: 5;

INVALID_SOCKET : Socket : ~0;
SOCKET_ERROR   :: -1;
INADDR_ANY     :: 0;

SD_RECEIVE :: 0;
SD_SEND    :: 1;
SD_BOTH    :: 2;

WSABASEERR     :: 10000;
WSAEWOULDBLOCK :: WSABASEERR+35;

Socket :: u64;
