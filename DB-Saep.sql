create table jogadores (
    id serial primary key,
    nickname varchar(50) unique not null,
    email varchar(100) unique not null,
    senha varchar(100) not null,
    status varchar(20) default 'ativo' check (status in ('ativo', 'banido', 'inativo')),
    data_cadastro timestamp default current_timestamp
);

create table modalidades (
    id serial primary key,
    nome_jogo varchar(100) not null,
    categoria varchar(50) not null
);

create table torneios (
    id serial primary key,
    modalidade_id int references modalidades(id),
    nome varchar(100) not null,
    data_inicio date not null,
    data_fim date not null,
    status varchar(20) default 'aberto' check (status in ('aberto', 'em andamento', 'finalizado'))
);

create table inscricoes (
    id serial primary key,
    jogador_id int references jogadores(id),
    torneio_id int references torneios(id),
    data_inscricao timestamp default current_timestamp,
    status varchar(20) default 'confirmada' check (status in ('confirmada', 'pendente', 'cancelada'))
);

create table partidas (
    id serial primary key,
    torneio_id int references torneios(id),
    jogador_id int references jogadores(id),
    titulo varchar(100) not null,
    data_agendamento timestamp not null,
    data_criacao timestamp default current_timestamp,
    status varchar(20) default 'agendada' check (status in ('agendada', 'em andamento', 'finalizada', 'cancelada'))
);

create table historico_partidas (
    id serial primary key,
    partida_id int references partidas(id),
    jogador_id int references jogadores(id),
    acao varchar(100) not null,
    data_log timestamp default current_timestamp
);

insert into jogadores (nickname, email, senha, status) values
('xmiguelitox10', 'miguel@email.com', '123456', 'Banido'),
('zxrayoo', 'jonga@email.com', '123456', 'Ativo'),
('nahhttan', 'nathan@email.com', '123456', 'Ativo');

insert into modalidades (nome_jogo, categoria) values
('minecraft', 'survival'),
('roblox', 'sandbox'),
('marvel rivals', 'hero-shooter');

insert into torneios (modalidade_id, nome, data_inicio, data_fim, status) values
(1, 'campeonato minecraft', '2026-12-01', '2026-12-10', 'aberto'),
(2, 'campeonato roblox', '2026-12-05', '2026-12-15', 'aberto'),
(3, 'campeonato marvel rivals', '2026-12-10', '2026-12-20', 'aberto');

insert into inscricoes (jogador_id, torneio_id, status) values
(1, 1, 'Cancelada'),
(2, 2, 'Confirmada'),
(3, 3, 'Confirmada');

insert into partidas (torneio_id, jogador_id, titulo, data_agendamento, status) values
(1, 1, 'xmiguelitox10 vs nahhttan', '2026-12-02 14:00:00', 'Cancelada'),
(2, 2, 'nahhttan vs zxrayoo', '2026-12-06 16:00:00', 'Cancelada'),
(3, 3, 'zxrayoo vs nahhttan', '2026-12-11 18:00:00', 'Em andamento');

create view vw_painel_principal as
select
    j.nickname,
    p.titulo as partida,
    m.categoria,
    p.data_agendamento as data_partida,
    p.status
from partidas p
join jogadores j on p.jogador_id = j.id
join torneios t on p.torneio_id = t.id
join modalidades m on t.modalidade_id = m.id;

create function fn_buscar_jogadores(p_termo varchar)
returns table (
    id int,
    nickname varchar,
    email varchar,
    status varchar
)
language plpgsql
as $$
begin
    return query
    select j.id, j.nickname, j.email, j.status
    from jogadores j
    where lower(j.nickname) = lower(p_termo)
       or lower(j.email) = lower(p_termo);
end;
$$;

create function fn_validar_partida()
returns trigger
language plpgsql
as $$
declare
    v_status varchar(20);
begin
    select j.status into v_status
    from jogadores j
    where j.id = new.jogador_id;

    if v_status is null or v_status <> 'ativo' then
        raise exception 'jogador nao esta ativo';
    end if;

    new.data_criacao = current_timestamp;

    return new;
end;
$$;

create trigger trg_validar_partida
before insert on partidas
for each row
execute function fn_validar_partida();

create function fn_registrar_historico()
returns trigger
language plpgsql
as $$
begin
    insert into historico_partidas (partida_id, jogador_id, acao)
    values (new.id, new.jogador_id, 'partida cadastrada');

    return new;
end;
$$;

create trigger trg_historico_partidas
after insert on partidas
for each row
execute function fn_registrar_historico();

create view vw_cronograma_partidas as
select
    p.id as partida_id,
    p.titulo as partida,
    p.data_agendamento,
    p.status,
    (p.data_agendamento::date - current_date) as dias_restantes,
    j.nickname
from partidas p
join jogadores j on p.jogador_id = j.id
order by p.data_agendamento asc;
