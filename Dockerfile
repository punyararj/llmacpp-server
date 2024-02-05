FROM nvidia/cuda:11.8.0-devel-ubuntu22.04
# docker pull ghcr.io/abetlen/llama-cpp-python:v0.2.23
# FROM python:3.11
# FROM ghcr.io/abetlen/llama-cpp-python:v0.2.23
RUN apt update && apt upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata
RUN apt install software-properties-common -y
RUN add-apt-repository ppa:deadsnakes/ppa -y
RUN apt update && apt install -y python3.11 python3.11-full wget ocl-icd-opencl-dev opencl-headers clinfo \
    libclblast-dev libopenblas-dev \
    && mkdir -p /etc/OpenCL/vendors && echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd

RUN ln -s /usr/bin/python3.11 /usr/bin/python
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py

# upgrade pip
RUN pip install --upgrade pip
# RUN apt-get update && apt-get install -y git curl gcc gfortran musl-dev g++ make cmake libstdc++6
# get curl for healthchecks
# RUN apt-get install -y curl python3.9 python3.9-dev gcc gfortran musl-dev g++ make cmake python3.9-distutils python3.9-venv

# LLamaCPP
# Install the deps
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/GMT
RUN apt-get update && apt-get install -y --no-install-recommends git cmake

# Get llama-cpp-python
WORKDIR /usr/src
RUN git clone https://github.com/abetlen/llama-cpp-python.git 
#RUN git clone https://github.com/gjmulder/llama-cpp-python.git
WORKDIR /usr/src/llama-cpp-python
#RUN git checkout improved-unit-tests

# Patch .gitmodules to use HTTPS
# RUN sed -i 's|git@github.com:ggerganov/llama.cpp.git|https://github.com/ggerganov/llama.cpp.git|' .gitmodules
# RUN git submodule update --init --recursive

ENV LLAMA_CUBLAS=1
ENV CUDA_DOCKER_ARCH=all
# Build llama-cpp-python w/CuBLAS
RUN grep --colour "n_batch" ./llama_cpp/server/*.py
RUN pip install scikit-build fastapi sse_starlette uvicorn
RUN CMAKE_ARGS="-DLLAMA_CUBLAS=on" pip install llama-cpp-python



#COPY /home/avalant/anaconda3/envs/llm/lib/libstdc++.so.6.0.29 /lib/x86_64-linux-gnu/libstdc++.so.6

# permissions and nonroot user for tightened security

#RUN adduser -D nonroot
ARG USERNAME=nonroot
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    #
    # [Optional] Add sudo support. Omit if you don't need to install software after connecting.
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

#COPY /home/avalant/anaconda3/envs/llm/lib/libstdc++.so.6.0.29 /lib/x86_64-linux-gnu/libstdc++.so.6

# ********************************************************
# * Anything else you want to do like clean up goes here *
# ********************************************************

# [Optional] Set the default user. Omit if you want to keep the default as root.
#USER $USERNAME

RUN mkdir /home/app/ && chown -R nonroot:nonroot /home/app
RUN mkdir -p /var/log/flask-app && touch /var/log/flask-app/flask-app.err.log && touch /var/log/flask-app/flask-app.out.log
RUN chown -R nonroot:nonroot /var/log/flask-app
WORKDIR /home/app

USER nonroot

# copy all the files to the container
COPY --chown=nonroot:nonroot . .

# venv
ENV VIRTUAL_ENV=/home/app/venv
# python setup
RUN python -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN export FLASK_APP=app.py
# upgrade pip
RUN pip install --upgrade pip
RUN pip install --upgrade pytest cmake scikit-build setuptools fastapi uvicorn sse-starlette pydantic-settings starlette-context
RUN CMAKE_ARGS="-DLLAMA_CUBLAS=on" pip install llama-cpp-python

# define the port number the container should expose
EXPOSE 8080

CMD ["python", "-m", "llama_cpp.server", "--config_file", "/app/app.config"]