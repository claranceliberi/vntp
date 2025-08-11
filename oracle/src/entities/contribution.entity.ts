import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, Index } from 'typeorm';

@Entity('contribution')
export class Contribution {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 50 })
  @Index()
  period: string;

  @Column({ name: 'rssb_number', type: 'varchar', length: 50 })
  @Index()
  rssbNumber: string;

  @Column({ type: 'varchar', length: 50 })
  matricule: string;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amount: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}