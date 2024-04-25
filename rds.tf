# RDS Subnet Group 생성
resource "aws_db_subnet_group" "db-subnet-group" {
  name = "three-tier-db-subnet-group"
  subnet_ids = [aws_subnet.prv_sub_961018_1_db.id, aws_subnet.prv_sub_961018_2_db.id]
    # 서브넷에 이미 소속 VPC, AZ 정보를 입력하여 생성하였기 때문에, 서브넷 id만 나열해주면 subnet group 생성
}
# DB 보안 그룹 생성
resource "aws_security_group" "db-sg" {
  name = "db-sg"
  description = "database security group"
  vpc_id = aws_vpc.my_vpc_961018.id

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks =[aws_subnet.prv_sub_961018_1_db.cidr_block]
  }

  egress { # 보안 그룹 생성 시, Outbound 허용을 직접 지정해줘야 통신 가능(관리 콘솔은 자동 생성 / 테라폼은 지정 필수)
    from_port = 0
    to_port = 0
    protocol = "-1" # Protocol -1은 전체 프로토콜을 의미
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "db-sg"
  }
}
# RDS특 -> 옵션 존나많음
resource "aws_rds_cluster" "aurora-mysql-db" {
  cluster_identifier = "database-1" # RDS Cluster 식별자명
  engine_mode = "provisioned" # DB 인스턴스 생성 시 Provisioned(미설정 시 default) 또는 Serverless 모드 지정
  db_subnet_group_name = aws_db_subnet_group.db-subnet-group.name # DB가 배치될 서브넷 그룹(.name으로 지정)
  vpc_security_group_ids = [aws_security_group.db-sg.id] # db 보안그룹 지정
  engine = "aurora-mysql" # 엔진 유형
  engine_version = "5.7.mysql_aurora.2.11.1" # 엔진 버전
  availability_zones = ["ap-southeast-1a", "ap-southeast-1b"] # 가용 영역
  database_name = "privatedb" # 이름 명칭 구문 까다로움 (특수문자 들어가면 안됌)
  master_username = "root" # 인스턴스에서 직접 제어되는 DB Master User Name
  master_password = "aktmxj12"
  skip_final_snapshot = true # RDS 삭제 시, 스냅샷 생성 X (true값으로 설정 시, terraform destroy 정상 수행 가능)
}

output "rds_writer_endpoint" { # rds cluster의 writer 인스턴스 endpoint 추출 (mysql 설정 및 Three-tier 연동파일에 정보 입력 필요해서 추출)
  value = aws_rds_cluster.aurora-mysql-db.endpoint # 해당 추출값은 terraform apply 완료 시 또는 terraform output rds_writer_endpoint로 확인 가능
}

resource "aws_rds_cluster_instance" "aurora-mysql-db-instance" {
  count = 1 # RDS Cluster에 속한 총 2개의 DB 인스턴스 생성 (Reader/Writer로 지정)
  identifier = "database-1-${count.index}" # Instance의 식별자명 (count index로 0번부터 1씩 상승)
  cluster_identifier = aws_rds_cluster.aurora-mysql-db.id # 소속될 Cluster의 ID 지정
  instance_class = "db.t3.small" # DB 인스턴스 Class (메모리 최적화/버스터블 클래스 선택 없이 type명만 적으면 됌)
  engine = "aurora-mysql"
  engine_version = "5.7.mysql_aurora.2.11.1"
}