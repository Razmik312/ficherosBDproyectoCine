-- 1
select a.Id_Actor as IdActor, a.Nombre  as Nombre_Actor, a.Apellido  as ApellidoActor,
if (count(aap.pelicula_id_pelicula)=0, 'NO HA ACTUADO', count(aap.pelicula_id_pelicula)) as NumPeliculas 
from actor a left join actor_actua_pelicula aap 
on a.Id_Actor = aap.actor_Id_Actor 
group by a.Id_Actor, a.Nombre, a.Apellido 
order by NumPeliculas desc;


-- 2
select c.nombre_cine, s.id_sala, s.capacidad, s.tipo, c.Id_Cine 
from cine c inner join sala s 
on c.id_cine = s.cine_id_cine
    inner join proyeccion p 
    on s.id_sala = p.sala_id_sala
where  s.capacidad = (
        select max(s2.capacidad)
        from sala s2
        where s2.cine_id_cine = c.id_cine
        )
group by c.id_cine, c.nombre_cine, s.id_sala, s.capacidad, s.tipo, c.Id_Cine 
order by c.Id_Cine asc;


-- 3
select c.id_cine, c.nombre_cine, c.ciudad, avg(s.precio) as precio_promedio 
from cine c inner join sala s 
on c.id_cine = s.cine_id_cine 
group by c.id_cine, c.nombre_cine, c.ciudad 
order by precio_promedio desc;


-- 4
select concat(a.apellido, ' ', a.nombre) as nombre_completo, count(ap.pelicula_Id_Pelicula) as peliculas
from actor a
inner join actor_actua_pelicula ap on a.id_actor = ap.actor_id_actor
group by a.id_actor, a.apellido, a.nombre
having count(ap.pelicula_id_pelicula) > (
    select avg(peliculas_por_actor) 
    from (
        select count(*) as peliculas_por_actor
        from actor_actua_pelicula
        group by actor_id_actor
    ) as peliculas_por_actor
)
order by a.Apellido;

-- Media de peliculas de un actor
select AVG(peliculas_por_actor) as promedio_peliculas_por_actor
from (
    select COUNT(*) AS peliculas_por_actor
    from actor_actua_pelicula
    group by actor_id_actor
) as media;



-- 5
select a.nombre, a.apellido, a.fecha_nacimiento, count(ap.pelicula_id_pelicula) as total_peliculas
from actor a left join actor_actua_pelicula ap 
on a.id_actor = ap.actor_id_actor
group by a.id_actor, a.nombre, a.apellido, a.fecha_nacimiento
having a.fecha_nacimiento <= all (
    select a2.fecha_nacimiento 
    from actor a2
)
order by total_peliculas asc;






-- VISTAS

-- 1
create view promedio_precios_cines as
select c.id_cine, c.nombre_cine, c.ciudad, avg(s.precio) as precio_promedio 
from cine c inner join sala s 
on c.id_cine = s.cine_id_cine 
group by c.id_cine, c.nombre_cine, c.ciudad 
order by precio_promedio desc;


-- 2
create view mayorCapacidadSala_cine as
select c.nombre_cine, s.id_sala, s.capacidad, s.tipo, c.Id_Cine 
from cine c inner join sala s 
on c.id_cine = s.cine_id_cine
    inner join proyeccion p 
    on s.id_sala = p.sala_id_sala
where  s.capacidad = (
        select max(s2.capacidad)
        from sala s2
        where s2.cine_id_cine = c.id_cine
        )
group by c.id_cine, c.nombre_cine, s.id_sala, s.capacidad, s.tipo, c.Id_Cine 
order by c.Id_Cine asc;






-- FUNCIONES

-- 1 
delimiter &&
create function contarProyeccionesPorPelicula(p_id_pelicula int)
returns int
deterministic
begin
    declare conteo int default 0;
    -- verificar si la película existe
    if not exists (select id_pelicula from pelicula where id_pelicula = p_id_pelicula) then
        return -1; 
    end if;
    
    -- contar el número de proyecciones
    set conteo = (select count(*) 
                  from proyeccion 
                  where pelicula_Id_pelicula = p_id_pelicula);
    
    if conteo = 0 then
		return 0;
	end if;

	return conteo;

end &&
delimiter ;


show function status where db = 'proyectocine' and name = 'contarproyeccionesporpelicula';

select contarProyeccionesPorPelicula(342) as proyecciones;
select contarProyeccionesPorPelicula(5294) as proyecciones;
select contarProyeccionesPorPelicula(21) as proyecciones;




-- 2

delimiter &&
create function resenasPeliculaPositivaHora(p_id_pelicula int)
returns varchar(200)
deterministic
begin
    declare total int default 0;
    -- verificar si la película existe
    if not exists (select id_pelicula from pelicula where id_pelicula = p_id_pelicula) then
        return 'La película no existe'; 
    end if;
   
    -- Contar reseñas positivas de las proyecciones a las 15:00
    	select count(r.id_resena) into total
        from resena r  inner join proyeccion pr 
        on r.pelicula_id_pelicula = pr.pelicula_id_pelicula
        where r.pelicula_id_pelicula = p_id_pelicula
        and r.puntuacion >= 7
        and pr.hora_proyeccion = '15:00';
               
        if (total=0) then
             return 'La película cuando se proyecta a las 15:00 
					 no tiene una puntuación de reseñas mayores a un 7';
		end if;
                
	return concat('Número de reseñas positivas = ', total);
end &&
delimiter ;

select resenasPeliculaPositivaHora(241) as resenas_positivas;
select resenasPeliculaPositivaHora(3957) as resenas_positivas;
select resenasPeliculaPositivaHora(179) as resenas_positivas;






-- PROCEDIMIENTOS

-- 1. Muestra películas por cine.
delimiter &&
create procedure mostrarPeliculasPorCine(in p_id_cine int)
begin
    declare existe_cine int default 0;
    declare cantidad_peliculas int default 0;

    -- Verificar si el ID es negativo o mayor 25
    if p_id_cine <= 0 or p_id_cine > 25 then
        select 'ID de cine inválido. Debe estar entre 1 y 25' as Mensaje;
    else
        -- Verificar si el cine existe
        select count(*) into existe_cine from cine where id_cine = p_id_cine;
        if existe_cine > 0 then
        
            -- Contar la cantidad de películas en ese cine
            select count(distinct p.id_pelicula) into cantidad_peliculas
            from pelicula p
            inner join proyeccion pr on p.id_pelicula = pr.pelicula_id_pelicula
            inner join sala s on pr.sala_id_sala = s.id_sala and pr.sala_cine_id_cine = s.cine_id_cine
            where s.cine_id_cine = p_id_cine;

            if cantidad_peliculas > 0 then
                select distinct p.titulo as Pelicula
                from pelicula p
                inner join proyeccion pr on p.id_pelicula = pr.pelicula_id_pelicula
                inner join sala s on pr.sala_id_sala = s.id_sala and pr.sala_cine_id_cine = s.cine_id_cine
                where s.cine_id_cine = p_id_cine;
            else
                select 'Sin películas' as Mensaje;
            end if;
        end if;
    end if;
end &&
delimiter ;


call mostrarPeliculasPorCine(-3);
call mostrarPeliculasPorCine(2);




-- 2. Elimina un actor
delimiter &&
create procedure eliminarActor(in p_id_actor int)
begin
    declare existe_actor int default 0;
    declare nombre_actor varchar(250);

    -- Verificar si el actor existe
    select count(*) into existe_actor 
    from actor where id_actor = p_id_actor;

    if existe_actor = 0 then
        select 'el actor no existe' as mensaje;
    else
        -- Obtener el nombre del actor antes de eliminarlo
        select nombre into nombre_actor 
        from actor where id_actor = p_id_actor;
       
        -- Eliminar el actor (las relaciones se eliminarán 
        -- automáticamente de las peliculas en las que ha participado
        -- el actor por la opcion cascade en la tabla actor_actua_pelicula)
        delete from actor 
        where id_actor = p_id_actor;
       
        -- Mostrar mensaje con el nombre del actor eliminado
        select concat('El actor ', nombre_actor, ' ha sido eliminado') as mensaje;
    end if;
end &&
delimiter ;


call eliminarActor(999);
call eliminarActor(2223);




-- 3 Mostrar la cantidad de películas en las que ha actuado un actor por género

delimiter &&
create procedure contarPeliculasPorGeneroDeActor(in p_id_actor int)
begin
    declare existe_actor int default 0;
    
    -- Verificar si el actor existe
    select count(*) into existe_actor from actor where id_actor = p_id_actor;
    
    if existe_actor = 0 then
        select 'El actor no existe' as Mensaje;
    else
        -- Contar la cantidad de películas en las que ha actuado el actor por género
        select p.genero, count(distinct p.id_pelicula) as total_peliculas
        from pelicula p
        inner join actor_actua_pelicula ap on p.id_pelicula = ap.pelicula_id_pelicula
        where ap.actor_id_actor = p_id_actor
        group by p.genero;
    end if;
end &&
delimiter ;


call contarPeliculasPorGeneroDeActor(23);
call contarPeliculasPorGeneroDeActor(4209);




-- TRIGGERS


-- 1
drop trigger if exists validarduracionpelicula;
delimiter &&
create trigger validarDuracionPelicula
before insert on pelicula
for each row
begin
    declare msg_error text;

    if new.duracion < 60 then
        set msg_error = concat('error: la película "', new.titulo, '" tiene una duración de ', new.duracion, ' minutos, debe ser al menos 60.');
        signal sqlstate '45000'
        set message_text = msg_error;
    end if;
end &&

delimiter ;


insert into pelicula (Id_Pelicula, Titulo, Duracion, Genero, Sinopsis, Director, Anio_Lanzamiento)
values (600, 'Pelicula larga', 30, 'Accion', 'Una sinopsis', 'Director Z', '2025-05-14');


insert into pelicula (Id_Pelicula, Titulo, Duracion, Genero, Sinopsis, Director, Anio_Lanzamiento)
values (700, 'Pelicula corta', 30, 'Comedia', 'Una sinopsis', 'Director Z', '2023-02-24');





-- 2

delimiter &&
create trigger verificarEdadActor
before insert on actor
for each row
begin
    declare edad int;
    declare msg_error text;

    set edad = timestampdiff(year, new.fecha_nacimiento, curdate());

    if edad < 10 then
        set msg_error = concat('error: el actor ', new.nombre, ' ', new.apellido, ' tiene ', edad, ' años y no cumple con la edad mínima de 10.');
        signal sqlstate '45000'
        set message_text = msg_error;
    end if;
end &&

delimiter ;


insert into actor (id_actor, nombre, apellido, fecha_nacimiento)
values (3000, 'Manuel', 'Marcos', '2000-02-17');








delimiter &&
create trigger ajustarprecioporanioygenero
after update on pelicula
for each row
begin
    -- ajustar precio para acción o terror en salas vip
    if new.genero in ('acción', 'terror') then
        update sala s
        inner join proyeccion p on s.id_sala = p.sala_id_sala
        set s.precio = s.precio * 1.10
        where p.pelicula_id_pelicula = new.id_pelicula
        and s.tipo = 'vip';
    end if;

    -- ajustar precio para comedia en salas normal
    if new.genero = 'comedia' then
        update sala s
        inner join proyeccion p on s.id_sala = p.sala_id_sala
        set s.precio = s.precio * 0.95
        where p.pelicula_id_pelicula = new.id_pelicula
        and s.tipo = 'normal';
    end if;
end &&
delimiter ;
