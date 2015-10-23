using ToxCore;

[CCode (cprefix="ToxWrapper", lower_case_cprefix="tox_wrapper_")]
namespace Tox {
	public errordomain ErrNew {
	  Null,
	  Malloc,
	  PortAlloc,
	  BadProxy,
	  LoadFailed
	}

	public ErrNew? convert_err_new (ERR_NEW error) {
	  switch (error) {
	    case ERR_NEW.NULL:
	      return new ErrNew.Null ("One of the arguments to the function was NULL when it was not expected.");
	    case ERR_NEW.MALLOC:
	      return new ErrNew.Malloc ("The function was unable to allocate enough memory to store the internal structures for the Tox object.");
	    case ERR_NEW.PORT_ALLOC:
	      return new ErrNew.PortAlloc ("The function was unable to bind to a port.");
	    case ERR_NEW.PROXY_BAD_TYPE:
	      return new ErrNew.BadProxy ("proxy_type was invalid.");
	    case ERR_NEW.PROXY_BAD_HOST:
	      return new ErrNew.BadProxy ("proxy_type was valid but the proxy_host passed had an invalid format or was NULL.");
	    case ERR_NEW.PROXY_BAD_PORT:
	      return new ErrNew.BadProxy ("proxy_type was valid, but the proxy_port was invalid.");
	    case ERR_NEW.PROXY_NOT_FOUND:
	      return new ErrNew.BadProxy ("The proxy address passed could not be resolved.");
	    case ERR_NEW.LOAD_ENCRYPTED:
	      return new ErrNew.LoadFailed ("The byte array to be loaded contained an encrypted save.");
	    case ERR_NEW.LOAD_BAD_FORMAT:
	      return new ErrNew.LoadFailed ("The data format was invalid. This can happen when loading data that was saved by an older version of Tox, or when the data has been corrupted. When loading from badly formatted data, some data may have been loaded, and the rest is discarded. Passing an invalid length parameter also causes this error.");
			default:
				return null;
	  }
	}

	public errordomain ErrFriendAdd {
	  Null,
	  TooLong,
	  NoMessage,
	  OwnKey,
	  AlreadySent,
	  BadChecksum,
	  BadNospam,
	  Malloc
	}

	public errordomain ErrFriendDelete {
	  NotFound
	}
}
