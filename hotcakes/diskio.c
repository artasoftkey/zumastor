#define _XOPEN_SOURCE 500 /* pwrite */
#include <unistd.h>
#include <errno.h> 
#include "trace.h"

/* Sane pread/pwrite wrapper */

int diskio(int fd, void *data, size_t count, off_t offset, int write)
{
	while (count) {
		ssize_t retval;

		if (write)
			retval = pwrite(fd, data, count, offset);
		else
			retval = pread(fd, data, count, offset);

		if (retval == -1)
			return -errno;

		if (retval == 0)
			return -ERANGE;

		data += retval;
		offset += retval;
		count -= retval;
	}

	return 0;
}

#if 0 // these should be wrappers -- daniel
int fdread(int fd, void *data, size_t count)
{
	ssize_t retval;

	while (count) {
		retval = read(fd, data, count);

		if (retval == -1) {
			warn("%s failed %s", "read", strerror(errno));
			return -errno;
		}

		if (retval == 0) {
			warn("short %s", "read");
			return -ERANGE;
		}

		data += retval;
		count -= retval;
	}

	return 0;
}

int fdwrite(int fd, void const *data, size_t count)
{
	ssize_t retval;

	while (count) {
		retval = write(fd, data, count);

		if (retval == -1) {
			warn("%s failed %s", "write", strerror(errno));
			return -errno;
		}

		if (retval == 0) {
			warn("short %s", "write");
			return -ERANGE;
		}

		data += retval;
		count -= retval;
	}

	return 0;
}
#endif