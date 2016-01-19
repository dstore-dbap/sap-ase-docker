FROM centos:centos7

# To keep the image small we download from a URL
ENV ASE_DOWNLOADFILE http://your.fileserver.com/ASESERV1570134_0-20011142.TGZ

# Needed for ASE
RUN yum -y install libaio glibc.i686 tar && yum -y clean all

ADD responsefile /tmp/responsefile

# This may take up to 20 minutes, since sybase-installer is very slow
RUN cd /tmp \
    && curl $ASE_DOWNLOADFILE -uusername:password | tar -xzf - \
    && ./ebf*/setup.bin -f /tmp/responsefile -i silent -DAGREE_TO_SYBASE_LICENSE=true -DRUN_SILENT=true \
    && rm -rf /tmp/* \
    && rm -rf /opt/sybase/shared/SAPJRE-* \
    && rm -rf /opt/sybase/shared/ase/JRE-* \
    && rm -rf /opt/sybase/jre64 \
    && rm -rf /opt/sybase/SCC-* \
    && rm -rf /opt/sybase/sybuninstall \
    && rm -rf /opt/sybase/jConnect-* \
    && rm -rf /opt/sybase/DataAccess* \
    && rm -rf /opt/sybase/ASE-15_0/bin/diag* \
    && rm -rf /opt/sybase/OCS-15_0/devlib* \
    && ln -s /opt/sybase/SYBASE.sh /etc/profile.d/sybase.sh \
    && groupadd sybase \
    && useradd -g sybase -s /sbin/nologin sybase \
    && chown -R sybase:sybase /opt/sybase

ADD interfaces /opt/sybase/interfaces
