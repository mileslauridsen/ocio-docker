#Download base image centos 7
FROM centos:7 AS compile-image

RUN yum install -y centos-release-scl && yum install -y devtoolset-7 rh-python36

SHELL [ "/usr/bin/scl", "enable", "devtoolset-7", "rh-python36" ]

RUN yum -y install bzip2 git curl zlib-devel bzip2 bzip2-devel \
	readline-devel sqlite sqlite-devel openssl openssl-devel \
	wget libpng-devel freetype-devel git libtool libffi-devel \
	libtiff pkgconfig jasper libjpeg8 libjpeg-turbo-devel giflib-devel libwebp-devel \
	mesa-libGLw freeglut-devel jasper-devel glew-devel xorg-x11-util-macros

# Make a user for remaining installs
RUN useradd -m python_user

WORKDIR /home/python_user
ENV HOME /home/python_user
USER python_user

RUN mkdir -p $HOME/source && \
	mkdir -p $HOME/tmp/ociobuild && \
	mkdir -p $HOME/software/ocio && \
	mkdir -p $HOME/software/cmake

RUN cd $HOME/source && \
	git clone https://github.com/Kitware/CMake.git && \
	cd CMake && \
	git branch release && \
	./bootstrap --prefix=$HOME/software/cmake && \
	make && \
	make install

ENV PATH $HOME/software/cmake/bin:$PATH

RUN git clone git://github.com/pyenv/pyenv.git .pyenv

ENV HOME  /home/python_user
ENV PYENV_ROOT $HOME/.pyenv
ENV PATH $PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH

RUN pyenv install 3.7.7
RUN pyenv global 3.7.7
RUN pyenv rehash

ENV PYTHONPATH $HOME/.pyenv/versions/3.7.7/lib/python3.7/site-packages:$PYTHONPATH

RUN echo $PATH

RUN eval "$(pyenv init -)" && \
    cd $HOME/source && \
	git clone https://github.com/AcademySoftwareFoundation/OpenColorIO.git && \
	cd $HOME/tmp/ociobuild && \
	cmake -DOCIO_INSTALL_EXT_PACKAGES=ALL \
		-DPYTHON_LIBRARY=$$HOME/.pyenv/versions/3.7.7/lib \
		-DPYTHON_INCLUDE_DIR=$HOME/.pyenv/versions/3.7.7/include/python3.7m \
		-DPYTHON_EXECUTABLE=$HOME/.pyenv/versions/3.7.7/bin/python \
		-DCMAKE_INSTALL_PREFIX=$HOME/software/ocio $HOME/source/OpenColorIO && \
	make -j1 && \
	make install

#RUN ls $HOME/software/ocio
#RUN blah

FROM centos:centos7 AS runtime-image

RUN mkdir -p /home/python_user/software
COPY --from=compile-image /home/python_user/software/ocio/include /usr/local/include
COPY --from=compile-image /home/python_user/software/ocio/lib /usr/local/lib
COPY --from=compile-image /home/python_user/software/ocio/bin /usr/local/bin
COPY --from=compile-image /home/python_user/.pyenv /home/python_user/.pyenv
COPY --from=compile-image /usr/lib64 /usr/lib64
#COPY --from=compile-image /home/python_user/software/ocio/bin/ociobakelut /usr/bin/ociobakelut
#COPY --from=compile-image /home/python_user/software/ocio/bin/ociocheck /usr/bin/ociocheck
#COPY --from=compile-image /home/python_user/software/ocio/bin/ociochecklut /usr/bin/ociochecklut
#COPY --from=compile-image /home/python_user/software/ocio/bin/ociomakeclf /usr/bin/ociomakeclf
#COPY --from=compile-image /home/python_user/software/ocio/bin/ociowrite /usr/bin/ociowrite

ENV PATH=/usr/bin:/usr/local:$PATH
ENV HOME  /home/python_user
ENV PYENV_ROOT $HOME/.pyenv
ENV PATH $PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH
ENV PATH $HOME/.pyenv/versions/3.7.7/lib/python3.7/site-packages:$PATH
ENV PYTHONPATH $HOME/.pyenv/versions/3.7.7/lib/python3.7/site-packages:$PYTHONPATH
ENV PYTHONPATH /usr/local/lib/python3.7/site-packages:$PYTHONPATH
ENV LD_LIBRARY_PATH /usr/local/lib
RUN useradd -m python_user
RUN eval "$(pyenv init -)" && \
    pip install --upgrade pip && \
    pip install pyseq && \
    pip install pyyaml

WORKDIR /home/python_user
USER python_user

ENTRYPOINT ["python"]
