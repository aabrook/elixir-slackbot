FROM resin/rpi-raspbian

RUN apt-get update \
  && apt-get install -y wget git

# Debian has older Erlang package (R15) in official repositories, Elixir requires newer (R17)
RUN wget http://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
RUN sudo dpkg -i erlang-solutions_1.0_all.deb
RUN sudo apt-get update
RUN sudo apt-get install -y erlang
RUN rm erlang-solutions_1.0_all.deb

# compile Elixir from source
# http://elixir-lang.org/getting_started/1.html

RUN git clone https://github.com/elixir-lang/elixir.git
RUN cd elixir
RUN git checkout stable
RUN make clean test

CMD ["/bin/sh"]
